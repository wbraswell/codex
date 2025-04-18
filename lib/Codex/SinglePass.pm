package Codex::SinglePass;
use strict;
use warnings;
use Perl::Types qw(void string hashref);
use Getopt::Long qw(GetOptionsFromArray);
use Time::HiRes qw(sleep);

=head1 NAME

Codex::SinglePass - Non-interactive single-pass mode

=head1 SYNOPSIS

  use Codex::SinglePass;
  Codex::SinglePass::run_singlepass(@ARGV);

=head1 DESCRIPTION

Implements a single-pass, non-interactive mode analogous to the TS runSinglePass.

=head1 METHODS

=head2 run_singlepass(@args)

Parses options and executes the agent once, printing the assistant output.
=cut
sub run_singlepass {
    my @argv = @_;
    my $original_prompt;
    my $config_file;
    my $root_path;
    GetOptionsFromArray(
        \@argv,
        'original-prompt|p=s' => \$original_prompt,
        'config|c=s'          => \$config_file,
        'root|r=s'            => \$root_path,
    );
    $root_path //= '.';
    # Load configuration if provided
    my $cfg = {};
    if ($config_file) {
        require Codex::Config;
        no strict 'refs';
        $cfg = Codex::Config::load_config($config_file);
    }
    # Build initial messages
    my @messages;
    if (defined $original_prompt) {
        push @messages, { type => 'message', role => 'user', content => [ { type => 'input_text', text => $original_prompt } ] };
    }
    # Run agent loop once
    require Codex::Agent::Loop;
    my $agent = Codex::Agent::Loop->new(
        model                  => 'gpt-3.5-turbo',
        instructions           => '',
        config                 => $cfg,
        approvalPolicy         => { mode => 'auto' },
        onItem                 => sub {
            my ($item) = @_;
            # Print assistant messages
            if ($item->{type} && $item->{type} eq 'message') {
                my $content = $item->{content};
                # content is arrayref of parts
                if (ref $content eq 'ARRAY' && @$content) {
                    print $content->[0]{text} || '';
                }
            }
        },
        onLoading              => sub {},
        getCommandConfirmation => sub { { review => 'yes' } },
        onLastResponseId       => sub {},
    );
    $agent->run(\@messages);
    # Allow time for processing
    sleep(1);
    return;
}

1;
__END__