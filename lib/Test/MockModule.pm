package Test::MockModule;
use strict;
use warnings;

sub new {
    my ($class, $module) = @_;
    return bless { module => $module }, $class;
}

sub mock {
    my ($self, $method, $code) = @_;
    no strict 'refs';
    no warnings 'redefine';
    my $package = $self->{module};
    my $full    = $package . '::' . $method;
    *{$full} = $code;
}

1;