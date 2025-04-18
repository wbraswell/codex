package Codex::TUI;
use strict;
use warnings;
use Perl::Types qw(void string);
use Curses;

=head1 NAME

Codex::TUI - Curses-based terminal user interface for Codex CLI

=head1 SYNOPSIS

  use Codex::TUI;
  my $tui = Codex::TUI->new();
  $tui->display("Hello, world!");
  $tui->finish();

=head1 DESCRIPTION

Provides a minimal Curses-based UI for displaying Codex CLI responses.

=head1 METHODS

=head2 new()

Initializes Curses and returns a Codex::TUI instance.

=head2 display($text)

Clears the screen and displays the given text at the top.

=head2 finish()

Ends the Curses session and restores the terminal.

=cut

sub new {
    initscr();
    cbreak();
    noecho();
    keypad(stdscr, 1);
    return bless {}, __PACKAGE__;
}

sub display {
    my string $text = shift;
    clear();
    mvaddstr(0, 0, $text);
    refresh();
}

sub finish {
    endwin();
}

1;
__END__