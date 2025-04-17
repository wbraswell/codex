package Codex::Utils::ShortPath;
use strict;
use warnings;
use Perl::Types;

use Exporter 'import';
our @EXPORT_OK = qw(shorten_path short_cwd);

use Cwd;
use File::Spec;

=head1 NAME

Codex::Utils::ShortPath - Shorten filesystem paths for display

=head1 FUNCTIONS

=head2 shorten_path($path, $max_length)

Truncates a path to fit within max_length by prepending "~/..." if needed.

=head2 short_cwd($max_length)

Returns a shortened version of the current working directory.

=cut

sub shorten_path {
    my string $p = shift;
    my nonsigned_integer $max_length = shift // 40;
    my $home = $ENV{HOME};
    my string $display = defined $home && index($p, $home) == 0
        ? '~' . substr($p, length($home))
        : $p;
    return $display if length($display) <= $max_length;
    my @parts = File::Spec->splitdir($display);
    my string $result = '';
    for (my $i = $#parts; $i >= 0; $i--) {
        my @slice = @parts[$i..$#parts];
        my string $candidate = File::Spec->catfile('~', '...', @slice);
        if (length($candidate) <= $max_length) {
            $result = $candidate;
        } else {
            last;
        }
    }
    return $result || substr($display, -$max_length);
}

sub short_cwd {
    my nonsigned_integer $max_length = shift // 40;
    return shorten_path(Cwd::getcwd(), $max_length);
}

1;
__END__