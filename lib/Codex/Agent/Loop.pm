package Codex::Agent::Loop;
use strict;
use warnings;
use Perl::Types qw(string hashref arrayref);
use Parallel::ForkManager;
use Mojo::UserAgent;
use Mojo::JSON qw(decode_json encode_json);
use Codex::Agent::HandleExecCommand qw(handle_exec_command);
use Time::HiRes qw(sleep);

=head1 NAME

Codex::Agent::Loop - Agent loop orchestrator (stub)

=cut

sub new {
    my ($class, %args) = @_;
    my $self = {
        model                  => $args{model},
        instructions           => $args{instructions},
        approvalPolicy         => $args{approvalPolicy},
        config                 => $args{config} // {},
        onItem                 => $args{onItem},
        onLoading              => $args{onLoading},
        getCommandConfirmation => $args{getCommandConfirmation},
        onLastResponseId       => $args{onLastResponseId},
        canceled               => 0,
        pendingAborts          => {},
        pm                     => Parallel::ForkManager->new(1),
        ua                     => Mojo::UserAgent->new(),
    };
    return bless $self, $class;
}

sub run {
    my ($self, $input) = @_;
    # Use Parallel::ForkManager to fork the streaming loop
    my $pm = $self->{pm};
    # Notify loading start in parent
    $self->{onLoading}->(1) if $self->{onLoading};
    $pm->run_on_finish(sub {
        my ($pid, $exit_code, $ident, $signal, $core_dump, $data) = @_;
        # Notify loading end in parent
        $self->{onLoading}->(0) if $self->{onLoading};
    });
    # Fork and run stream in child
    $pm->start and return;
    $self->_stream_loop($input);
    $pm->finish;
}

sub cancel {
    my ($self) = @_;
    # Mark as canceled to stop processing in child
    $self->{canceled} = 1;
    return;
}
 
# Internal run loop executed in a separate thread
sub _stream_loop {
    my ($self, $input) = @_;
    # Build chat-completion request with streaming
    my @msgs = (
        { role => 'system', content => "You are Codex CLI, a helpful coding assistant." },
    );
    for my $item (@$input) {
        next unless $item->{type} && $item->{type} eq 'message';
        push @msgs, { role => $item->{role}, content => $item->{content} };
    }
    my $body = encode_json({ model => $self->{model}, messages => \@msgs, stream => Mojo::JSON::true });
    my $url  = 'https://api.openai.com/v1/chat/completions';
    # Prepare transaction
    my $tx = $self->{ua}->build_tx(
        POST => $url,
        { 'Content-Type' => 'application/json', Authorization => "Bearer $ENV{OPENAI_API_KEY}" },
        $body,
    );
    # Stream SSE chunks
    $tx->res->on(data => sub {
        my ($res, $chunk) = @_;
        for my $part (split /\r?\n\r?\n/, $chunk) {
            next unless $part =~ s/^data: //;
            next if $part eq '[DONE]';
            my $j = eval { decode_json($part) };
            next unless $j && ref $j eq 'HASH';
            for my $choice (@{ $j->{choices} || [] }) {
                my $delta = $choice->{delta} || {};
                # Handle content deltas
                if (exists $delta->{content}) {
                    my $text = $delta->{content} // '';
                    $self->{onItem}->({ type => 'message', role => 'assistant', content => [ { type => 'input_text', text => $text } ] });
                }
                # Handle function_call deltas
                if (exists $delta->{function_call}) {
                    my $fc        = $delta->{function_call};
                    my $name      = $fc->{name} // '';
                    my $args_text = $fc->{arguments} // '';
                    # emit function_call event
                    $self->{onItem}->({
                        type      => 'function_call',
                        name      => $name,
                        arguments => $args_text,
                    });
                    # parse arguments and execute command
                    my $args = {};
                    eval { $args = decode_json($args_text) // {} }; # decode JSON args
                    my $res = handle_exec_command(%{ $args });
                    # emit function_call_output event
                    $self->{onItem}->({
                        type     => 'function_call_output',
                        name     => $name,
                        output   => $res->{outputText},
                        metadata => $res->{metadata},
                    });
                    # emit any additional items returned
                    for my $item (@{ $res->{additionalItems} || [] }) {
                        $self->{onItem}->($item);
                    }
                }
            }
        }
    });
    # Start and block until complete
    $self->{ua}->start($tx);
}

sub terminate {
    my ($self) = @_;
    # TODO: final cleanup
    return;
}

1;