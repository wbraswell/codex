package Codex::TUI::History;
use strict;
use warnings;
use Perl::Types qw(void string arrayref nonsigned_integer);
use Curses qw(getmaxyx);

sub new {
    my ($class, %args) = @_;
    my $win = $args{win} or die "win parameter required";
    my ($maxy, $maxx) = getmaxyx($win);
    my $self = {
        win       => $win,
        msgs      => [],
        max_lines => $maxy,
    };
    return bless $self, $class;
}

sub add {
    my ($self, $text) = @_;
    push @{ $self->{msgs} }, $text;
    if (@{ $self->{msgs} } > $self->{max_lines}) {
        my $start = @{ $self->{msgs} } - $self->{max_lines};
        @{ $self->{msgs} } = @{ $self->{msgs} }[$start .. -1];
    }
}

sub draw {
    my ($self) = @_;
    my $win = $self->{win};
    $win->clear();
    my $y = 0;
    for my $line (@{ $self->{msgs} }) {
        $win->mvaddstr($y++, 0, $line);
    }
    $win->refresh();
}

1;