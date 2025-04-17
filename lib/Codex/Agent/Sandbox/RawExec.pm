package Codex::Agent::Sandbox::RawExec;
use strict;
use warnings;
use Exporter 'import';

our @EXPORT_OK = qw(
    exec
);

=head1 NAME

Codex::Agent::Sandbox::RawExec - raw execution sandbox stub

=cut

sub exec {
    my ($cmd, $opts, $writableRoots, $abortSignal) = @_;
    # TODO: implement raw execution
    die "raw exec not implemented";
}

1;