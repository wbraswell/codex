package Codex::CLI;
use strict;
use warnings;
use Perl::Types qw(void boolean integer nonsigned_integer number character string hash hashref array arrayref);

=head1 NAME

Codex::CLI - Command-line interface for Codex

=cut

use Cwd 'abs_path';
use File::Spec;
use Getopt::Long qw(GetOptionsFromArray);
use HTTP::Tiny;
use JSON;

sub run {
    my %opts;
    my @argv = @_ ? @_ : @ARGV;
    # Global options: help and model
    my ($help, $model) = (undef, 'gpt-3.5-turbo');
    GetOptionsFromArray(
        \@argv,
        'help|h'    => \$help,
        'model|m=s' => \$model,
    );
    # Show usage if requested
    if ($help) {
        _usage();
        return;
    }
    # Require subcommand or prompt
    unless (@argv) {
        _usage();
        return;
    }
    # Handle 'completion' subcommand (shell completions)
    if ($argv[0] eq 'completion') {
        shift @argv;
        my $shell = $argv[0] // 'bash';
        print "# Completion script for codex ($shell) not implemented yet\n";
        return;
    }
    # Handle 'apply-patch' subcommand
    if ($argv[0] eq 'apply-patch') {
        shift @argv;
        local $/;
        my $patch_text = <>;
        require Codex::Exec;
        my $result = Codex::Exec::exec_apply_patch(
            $patch_text,
            sub { my ($path) = @_; local $/; open my $fh, '<', $path or return ''; <$fh> },
            sub { my ($path, $content) = @_; open my $fh, '>', $path or die $!; print $fh $content },
            sub { my ($path) = @_; unlink $path },
        );
        print JSON->new->utf8->encode($result), "\n";
        return;
    }
    # Handle 'exec' subcommand
    if ($argv[0] eq 'exec') {
        shift @argv;
        my @cmd = @argv;
        require Codex::Agent::Sandbox::RawExec;
        my $res = Codex::Agent::Sandbox::RawExec::exec(\@cmd, {}, undef, undef);
        print JSON->new->utf8->encode($res), "\n";
        return;
    }
    # Handle cluster-prompts example
    if ($argv[0] eq 'cluster-prompts') {
        shift @argv;
        my $self_file = abs_path(__FILE__);
        my (undef, $dirs) = File::Spec->splitpath($self_file);
        my @parts = File::Spec->splitdir($dirs);
        # repo root assumed two levels up from lib/Codex
        my $root = File::Spec->catdir(@parts[0 .. $#parts-2]);
        my $script = File::Spec->catfile($root, 'examples', 'prompt_analyzer', 'cluster_prompts.pl');
        exec $^X, $script, @argv;
        die "Failed to exec $script: $!";
    }
    # Default: interactive chat loop with Curses-based UI
    require Codex::TUI;
    my $tui      = Codex::TUI->new();
    my $api_key  = $ENV{OPENAI_API_KEY} or die "Missing OPENAI_API_KEY environment variable\n";
    my $http     = HTTP::Tiny->new;
    my $endpoint = 'https://api.openai.com/v1/chat/completions';
    my @messages = (
        { role => 'system', content => "You are Codex CLI, a helpful coding assistant." },
    );
    my @functions = (
        { name => 'apply_patch', description => 'Apply a textual patch to files',
          parameters => { type => 'object', properties => { patch_text => { type => 'string' } }, required => ['patch_text'] },
        },
        { name => 'shell', description => 'Run a shell command',
          parameters => { type => 'object', properties => { command => { type => 'array', items => { type => 'string' } }, workdir => { type => 'string' }, timeout => { type => 'number' } }, required => ['command'] },
        },
    );
    while (1) {
        my $user_input = $tui->prompt_input();
        last unless defined $user_input;
        if ($user_input eq ':quit') {
            last;
        }
        if ($user_input eq ':help') {
            $tui->show_help();
            next;
        }
        if ($user_input eq ':model') {
            $tui->show_model_info($model);
            next;
        }
        push @messages, { role => 'user', content => $user_input };
        my $body = {
            model         => $model,
            messages      => [@messages],
            functions     => \@functions,
            function_call => 'auto',
        };
        # Throttle to avoid API rate limits
        sleep 5;
        # Send request
        my $resp = $http->post($endpoint, {
            headers => { 'Content-Type' => 'application/json', 'Authorization' => "Bearer $api_key" },
            content => JSON->new->utf8->encode($body),
        });
        die "OpenAI API error: $resp->{status} $resp->{reason}\n" unless $resp->{success};
        my $res = JSON->new->utf8->decode($resp->{content});
        my $msg = $res->{choices}[0]{message} || {};
        # Handle function call
        if (exists $msg->{function_call}) {
            my $fc   = $msg->{function_call};
            my $name = $fc->{name};
            my $args = eval { JSON->new->utf8->decode($fc->{arguments} // '{}') } || {};
            my $out;
            if ($name eq 'apply_patch') {
                # Prompt user to approve the patch before applying
                my $patch_text = $args->{patch_text} // '';
                my $approved   = $tui->show_approval($patch_text);
                if ($approved) {
                    require Codex::Exec;
                    $out = Codex::Exec::exec_apply_patch(
                        $patch_text,
                        sub { my ($path) = @_; local $/; open my $fh, '<', $path or return ''; <$fh> },
                        sub { my ($path, $content) = @_; open my $fh, '>', $path or die $!; print $fh $content },
                        sub { my ($path) = @_; unlink $path },
                    );
                }
                else {
                    $out = { stdout => '', stderr => 'User rejected patch', exitCode => 1 };
                }
            }
            elsif ($name eq 'shell') {
                require Codex::Agent::Sandbox::RawExec;
                $out = Codex::Agent::Sandbox::RawExec::exec($args->{command} || [], {}, undef, undef);
            } else {
                die "Unknown function: $name\n";
            }
            push @messages, { role => 'assistant', function_call => $fc };
            push @messages, { role => 'function', name => $name, content => JSON->new->utf8->encode($out) };
            next;
        }
        # Regular assistant message
        my $content = $msg->{content} // '';
        $tui->display($content);
        push @messages, { role => 'assistant', content => $content };
    }
    # Tear down UI
    $tui->finish();
}
1;

sub _usage {
    print <<"USAGE";
Usage: codex [--model MODEL] <prompt text>
       codex cluster-prompts [options]

Options:
  -h, --help         Show this help message
  -m, --model MODEL  LLM model to use (default: gpt-3.5-turbo)

Subcommands:
  cluster-prompts    Analyze text prompts via the Perl example script
USAGE
}
1;