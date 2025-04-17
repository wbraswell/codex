package Codex::Agent::Sandbox::MacOSSeatbelt;
use strict;
use warnings;
use Exporter 'import';

our @EXPORT_OK = qw(
    exec_with_seatbelt
);

=head1 NAME

Codex::Agent::Sandbox::MacOSSeatbelt - macOS seatbelt sandbox stub

=cut

sub exec_with_seatbelt {
    my ($cmd, $opts, $writableRoots, $abortSignal) = @_;
    # TODO: implement macOS seatbelt sandboxed execution
    die "exec_with_seatbelt not implemented";
}

1;