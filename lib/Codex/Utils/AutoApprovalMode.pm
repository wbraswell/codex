package Codex::Utils::AutoApprovalMode;
use strict;
use warnings;
use Perl::Types;

use Exporter 'import';
our @EXPORT_OK = qw(
    AutoApprovalMode
    FullAutoErrorMode
);

=head1 NAME

Codex::Utils::AutoApprovalMode - Constants for auto approval modes

=head1 DESCRIPTION

Defines the enums AutoApprovalMode and FullAutoErrorMode.

=cut

## Enum values for auto approval modes
my hashref $AUTO_APPROVAL_MODE = {
    SUGGEST   => 'suggest',
    AUTO_EDIT => 'auto-edit',
    FULL_AUTO => 'full-auto',
};

## Enum values for error handling in full auto mode
my hashref $FULL_AUTO_ERROR_MODE = {
    ASK_USER            => 'ask-user',
    IGNORE_AND_CONTINUE => 'ignore-and-continue',
};

sub AutoApprovalMode      { return $AUTO_APPROVAL_MODE }
sub FullAutoErrorMode     { return $FULL_AUTO_ERROR_MODE }

1;
__END__