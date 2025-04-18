package Codex::TUI;
use strict;
use warnings;
use Perl::Types qw(void string);
use Curses qw(initscr cbreak noecho curs_set keypad getmaxyx newwin clear refresh box endwin KEY_ENTER KEY_BACKSPACE);

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
    curs_set(0);
    keypad(stdscr, 1);
    my ($maxy, $maxx) = getmaxyx(stdscr);
    my $hist_height = $maxy - 3;
    my $history_win = newwin($hist_height, $maxx, 0, 0);
    my $suggest_win = newwin(2,           $maxx, $hist_height, 0);
    my $input_win   = newwin(1,           $maxx, $hist_height + 2, 0);
    keypad($history_win, 1);
    keypad($suggest_win, 1);
    keypad($input_win, 1);
    require Codex::TUI::History;
    require Codex::TUI::Typeahead;
    my $self = bless {
        history   => Codex::TUI::History->new(win => $history_win),
        typeahead => Codex::TUI::Typeahead->new(win => $suggest_win),
        input_win => $input_win,
    }, __PACKAGE__;
    return $self;
}

sub display {
    my ($self, $text) = @_;
    $self->{history}->add($text);
    $self->_redraw();
}
 
sub prompt_input {
    my ($self) = @_;
    my string $buffer = '';
    $self->{typeahead}->update($buffer);
    $self->_draw_input($buffer);
    while (1) {
        my $ch = $self->{input_win}->getch();
        last unless defined $ch;
        if ($ch == KEY_ENTER || $ch == 10 || $ch == 13) {
            last;
        }
        elsif ($ch == KEY_BACKSPACE || $ch == 127) {
            chop $buffer;
        }
        elsif ($ch >= 32 && $ch <= 126) {
            $buffer .= chr($ch);
        }
        $self->{typeahead}->update($buffer);
        $self->_draw_input($buffer);
    }
    return $buffer;
}

sub show_help {
    my ($self) = @_;
    my @lines = (
        'Codex CLI Help',
        '',
        'Enter your prompt at the bottom.',
        'Type ":quit" to exit.',
        '',
        'Press any key to close this help.'
    );
    my ($maxy, $maxx) = getmaxyx(stdscr);
    my $height = @lines + 2;
    my $width  = 0;
    $width = length($_) > $width ? length($_) : $width for @lines;
    my $starty = int(($maxy - $height) / 2);
    my $startx = int(($maxx - $width)  / 2);
    my $win = newwin($height, $width, $starty, $startx);
    box($win, 0, 0);
    for my $i (0 .. $#lines) {
        $win->mvaddstr($i+1, 1, $lines[$i]);
    }
    $win->refresh();
    $win->getch();
    $win->clear();
    $win->refresh();
    $self->_redraw();
}

sub show_model_info {
    my ($self, $model) = @_;
    my @lines = (
        "Model in use: $model",
        '',
        'Press any key to continue.'
    );
    my ($maxy, $maxx) = getmaxyx(stdscr);
    my $height = @lines + 2;
    my $width  = 0;
    $width = length($_) > $width ? length($_) : $width for @lines;
    my $starty = int(($maxy - $height) / 2);
    my $startx = int(($maxx - $width)  / 2);
    my $win = newwin($height, $width, $starty, $startx);
    box($win, 0, 0);
    for my $i (0 .. $#lines) {
        $win->mvaddstr($i+1, 1, $lines[$i]);
    }
    $win->refresh();
    $win->getch();
    $win->clear();
    $win->refresh();
    $self->_redraw();
}

=head2 show_approval($patch_text)

Display a patch overlay and prompt for Yes/No approval.
=cut
sub show_approval {
    my ($self, $patch_text) = @_;
    require Codex::TUI::Approval;
    return Codex::TUI::Approval->new()->show($patch_text);
}

sub _redraw {
    my ($self) = @_;
    $self->{history}->draw();
    refresh();
}

sub _draw_input {
    my ($self, $buffer) = @_;
    my $win = $self->{input_win};
    $win->clear();
    $win->addstr(0, 0, "> $buffer");
    $win->refresh();
    $self->{typeahead}->draw();
}

sub finish {
    endwin();
}

1;
__END__