package Perl::Types;
use strict;
use warnings;
use Exporter 'import';

# Stub types for code port; no-op import
our @EXPORT_OK = qw(
    void
    boolean
    integer
    nonsigned_integer
    number
    character
    string
    hash
    hashref
    array
    arrayref
);

sub import { }

1;