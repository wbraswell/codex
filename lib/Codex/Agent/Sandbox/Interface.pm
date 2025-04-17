package Codex::Agent::Sandbox::Interface;
use strict;
use warnings;
use Exporter 'import';

our @EXPORT_OK = qw(
    ExecInput
    ExecResult
    SandboxType
);

=head1 NAME

Codex::Agent::Sandbox::Interface - Execution sandbox interface types

=cut

# Stub types for exec sandbox
sub ExecInput { }
sub ExecResult { }

# Sandbox types enumeration
sub SandboxType {
    return {
        MACOS_SEATBELT => 'macos-seatbelt',
        RAW            => 'raw',
    };
}

1;