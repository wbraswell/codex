use strict;
use warnings;
use Test::More tests => 6;
use lib qw(../lib);
use Codex::Exec qw(exec_apply_patch get_base_cmd);

# Helper FS
sub create_fs {
    my (%initial) = @_;
    my %files = %initial;
    my %writes;
    my @rem;
    my $open = sub { my $p = shift; return $files{$p}; };
    my $write = sub { my ($p, $c) = @_; $writes{$p} = $c; };
    my $remove = sub { my $p = shift; push @rem, $p; };
    return (
        open_fn   => $open,
        write_fn  => $write,
        remove_fn => $remove,
        writes_ref => \%writes,
        rem_ref    => \@rem,
    );
}

# Test create and update
{
    my $patch = <<'EOF';
*** Begin Patch
*** Add File: x.txt
+abc
*** Update File: y.txt
@@
-old
+new
*** End Patch
EOF
    my %fs = create_fs('y.txt' => 'old');
    my $res = exec_apply_patch(
        $patch,
        $fs{open_fn}, $fs{write_fn}, $fs{remove_fn}
    );
    is($res->{exitCode}, 0, 'Exit code zero');
    is($res->{stderr}, '', 'No stderr');
    is($res->{stdout}, 'Done!', 'stdout Done!');
    is_deeply($fs{writes_ref}, { 'x.txt' => 'abc', 'y.txt' => 'new' }, 'Writes correct');
}

# Test get_base_cmd
is(get_base_cmd(['bash','-lc',"'echo foo'" ]), 'echo foo', 'Strip bash -lc wrapper');
is(get_base_cmd(['git','commit']), 'git', 'Return first element');