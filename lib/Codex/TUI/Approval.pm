package Codex::TUI::Approval;
use strict;
use warnings;
use Perl::Types qw(void string);
use Curses qw(getmaxyx newwin box);

=head1 NAME

Codex::TUI::Approval - Popup approval overlay for patches

=head1 METHODS

=head2 new()

Constructor
=cut
sub new {
    my ($class) = @_;
    return bless {}, $class;
}

=head2 show($patch_text)

Display the given patch text in a popup, ask user Y/N, return boolean
=cut
sub show {
    my ($self, $patch_text) = @_;
    my @lines = split /\n/, $patch_text;
    my ($maxy, $maxx) = getmaxyx(stdscr);
    # Compute popup size
    my $width = 0;
    $width = length($_) > $width ? length($_) : $width for @lines;
    $width += 4;
    $width = $maxx - 2 if $width > $maxx - 2;
    my $height = @lines + 4;
    $height = $maxy - 2 if $height > $maxy - 2;
    my $starty = int(($maxy - $height) / 2);
    my $startx = int(($maxx - $width)  / 2);
    my $win = newwin($height, $width, $starty, $startx);
    box($win, 0, 0);
    # Display patch lines (truncated if needed)
    my $max_lines = $height - 4;
    for my $i (0 .. $max_lines - 1) {
        last if $i > $#lines;
        my $line = substr($lines[$i], 0, $width - 4);
        $win->mvaddstr(1 + $i, 2, $line);
    }
    # Prompt
    my $prompt = '[Y]es/[N]o to apply patch';
    $win->mvaddstr($height - 2, 2, $prompt);
    $win->refresh();
    # Wait for Y/N
    my $ch;
    while (1) {
        $ch = $win->getch();
        last if defined $ch && ($ch == ord('y') || $ch == ord('Y') || $ch == ord('n') || $ch == ord('N'));
    }
    $win->clear();
    $win->refresh();
    return ($ch == ord('y') || $ch == ord('Y')) ? 1 : 0;
}

1;
__END__