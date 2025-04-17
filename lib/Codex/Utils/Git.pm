package Codex::Utils::Git;
use strict;
use warnings;
use Perl::Types;

=head1 NAME

Codex::Utils::Git - Git-related utilities

=head1 FUNCTIONS

=head2 check_in_git($workdir)

Returns true if the given directory is inside a Git working tree.

=cut

sub check_in_git {
    my string $workdir = shift;
    use Cwd;
    my $orig = getcwd();
    chdir $workdir;
    # suppress output
    # use shell form to allow redirection
    my $ok = system("git rev-parse --is-inside-work-tree > /dev/null 2>&1") == 0;
    chdir $orig;
    return $ok ? 1 : 0;
}

1;
__END__