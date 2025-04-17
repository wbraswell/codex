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
    my ($cmd_aref, $opts, $writableRoots, $abortSignal) = @_;
    # Fallback to raw exec for now
    require Codex::Agent::Sandbox::RawExec;
    return Codex::Agent::Sandbox::RawExec::exec($cmd_aref, $opts, $writableRoots, $abortSignal);
}

1;