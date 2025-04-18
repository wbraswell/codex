package Codex::Agent::HandleExecCommand;
use strict;
use warnings;
use Exporter 'import';

our @EXPORT_OK = qw(
    handle_exec_command
);

=head1 NAME

Codex::Agent::HandleExecCommand - Stub for handle_exec_command

=cut

sub handle_exec_command {
    my (%args) = @_;
    # Default execution: run the command and capture output
    my $cmd_ref = $args{command} // [];
    my $output = '';
    if (ref $cmd_ref eq 'ARRAY' && @$cmd_ref) {
        # join command array into a string and execute
        my $cmd_str = join(' ', @$cmd_ref);
        $output = `$cmd_str 2>&1`;
    }
    return {
        outputText      => $output,
        metadata        => { exitCode => ($? >> 8) },
        additionalItems => [],
    };
}

1;