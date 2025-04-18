package Codex::TUI::Typeahead;
use strict;
use warnings;
use Perl::Types qw(void string arrayref);
use Curses;

sub new {
    my ($class, %args) = @_;
    my $win = $args{win} or die "win parameter required";
    my $self = {
        win         => $win,
        prefix      => '',
        suggestions => [],
    };
    return bless $self, $class;
}

sub update {
    my ($self, $prefix) = @_;
    $self->{prefix} = $prefix;
    my @cmds = qw(:help :model :quit);
    if ($prefix =~ /^:/) {
        # suggest meta-commands matching the prefix
        my @matches = grep { index($_, $prefix) == 0 } @cmds;
        $self->{suggestions} = \@matches;
    } else {
        $self->{suggestions} = [];
    }
}

sub draw {
    my ($self) = @_;
    my $win = $self->{win};
    $win->clear();
    my $i = 0;
    for my $s (@{ $self->{suggestions} }) {
        last if $i >= 2;
        $win->mvaddstr($i, 0, $s);
        $i++;
    }
    $win->refresh();
}

1;