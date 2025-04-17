package Codex::Agent::Review;
use strict;
use warnings;
use Exporter 'import';

our @EXPORT_OK = qw(
    ReviewDecision
);

=head1 NAME

Codex::Agent::Review - Stub for review decisions

=cut

# Review decision constants
sub ReviewDecision {
    return {
        APPROVE => 'approve',
        DENY    => 'deny',
    };
}

1;