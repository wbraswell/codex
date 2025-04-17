package Codex::ParseApplyPatch;
use strict;
use warnings;
use Perl::Types qw(string arrayref hashref integer);
use Exporter 'import';
our @EXPORT_OK = qw(parse_apply_patch);

use constant {
    PATCH_PREFIX         => "*** Begin Patch\n",
    PATCH_SUFFIX         => '*** End Patch',
    ADD_FILE_PREFIX      => '*** Add File: ',
    DELETE_FILE_PREFIX   => '*** Delete File: ',
    UPDATE_FILE_PREFIX   => '*** Update File: ',
    END_OF_FILE_PREFIX   => '*** End of File',
    HUNK_ADD_LINE_PREFIX => '+',
};

=head1 NAME

Codex::ParseApplyPatch - Parse textual patches into operations

=head1 SYNOPSIS

  use Codex::ParseApplyPatch;
  my $ops = parse_apply_patch($patch_text);
  if (defined $ops) {
      # $ops is arrayref of hashrefs with keys: type, path, content/update, added, deleted
  }

=cut

sub parse_apply_patch {
    my ($patch) = @_;
    # remove trailing newline, if any
    chomp $patch;
    return undef unless defined $patch;
    return undef unless index($patch, PATCH_PREFIX) == 0;
    return undef unless substr($patch, -length(PATCH_SUFFIX)) eq PATCH_SUFFIX;

    my $body = substr($patch, length(PATCH_PREFIX), length($patch) - length(PATCH_PREFIX) - length(PATCH_SUFFIX));
    my @lines = split /\n/, $body;
    my @ops;

    for my $line (@lines) {
        if (index($line, END_OF_FILE_PREFIX) == 0) {
            next;
        } elsif (index($line, ADD_FILE_PREFIX) == 0) {
            push @ops, { type => 'create', path => substr($line, length(ADD_FILE_PREFIX)), content => '' };
            next;
        } elsif (index($line, DELETE_FILE_PREFIX) == 0) {
            push @ops, { type => 'delete', path => substr($line, length(DELETE_FILE_PREFIX)) };
            next;
        } elsif (index($line, UPDATE_FILE_PREFIX) == 0) {
            push @ops, { type => 'update', path => substr($line, length(UPDATE_FILE_PREFIX)), update => '', added => 0, deleted => 0 };
            next;
        }

        my $last = $ops[-1];
        next unless $last;
        if ($last->{type} eq 'create') {
            my $ln = substr($line, length(HUNK_ADD_LINE_PREFIX));
            $last->{content} = length($last->{content}) ? "$last->{content}\n$ln" : $ln;
            next;
        }
        return undef unless $last->{type} eq 'update';
        if (index($line, HUNK_ADD_LINE_PREFIX) == 0) {
            $last->{added}++;
        } elsif (index($line, '-') == 0) {
            $last->{deleted}++;
        }
        $last->{update} .= length($last->{update}) ? "\n$line" : $line;
    }

    return \@ops;
}

1;
__END__

=head1 LICENSE

Apache-2.0
=cut