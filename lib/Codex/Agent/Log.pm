package Codex::Agent::Log;
use strict;
use warnings;
use Exporter 'import';

our @EXPORT_OK = qw(
    is_logging_enabled
    log
);

=head1 NAME

Codex::Agent::Log - Simple logging controls

=cut

sub is_logging_enabled {
    return 0;
}

sub log {
    my ($msg) = @_;
    # Stub: no-op when logging disabled
    return;
}

1;