use strict;
use warnings;
use Test::More tests => 17;
use lib qw(../lib);
use Codex::ApplyPatch qw(process_patch identify_files_needed identify_files_added);

# Helper to simulate an in-memory filesystem
sub create_fs {
    my (%initial) = @_;
    my %files = %initial;
    my %writes;
    my @removals;
    my $open = sub {
        my ($p) = @_;
        die "File not found: $p" unless exists $files{$p};
        return $files{$p};
    };
    my $write = sub {
        my ($p, $content) = @_;
        $files{$p} = $content;
        $writes{$p} = $content;
    };
    my $remove = sub {
        my ($p) = @_;
        delete $files{$p};
        push @removals, $p;
    };
    return {
        open   => $open,
        write  => $write,
        remove => $remove,
        writes => \%writes,
        removals => \@removals,
        files  => \%files,
    };
}

# 1) update file
{
    my $patch = <<'PATCH';
*** Begin Patch
*** Update File: a.txt
@@
-hello
+hello world
*** End Patch
PATCH
    my $fs = create_fs('a.txt' => 'hello');
    my $res = process_patch($patch, $fs->{open}, $fs->{write}, $fs->{remove});
    is($res, 'Done!', 'process_patch returns Done! for update');
    is_deeply($fs->{writes}, { 'a.txt' => 'hello world' }, 'writes updated file');
    is_deeply($fs->{removals}, [], 'no removals');
}

# 2) add file
{
    my $patch = <<'PATCH';
*** Begin Patch
*** Add File: b.txt
+new content
*** End Patch
PATCH
    my $fs = create_fs();
    process_patch($patch, $fs->{open}, $fs->{write}, $fs->{remove});
    is_deeply($fs->{writes}, { 'b.txt' => 'new content' }, 'writes new file');
    is_deeply($fs->{removals}, [], 'no removals for add');
}

# 3) delete file
{
    my $patch = <<'PATCH';
*** Begin Patch
*** Delete File: c.txt
*** End Patch
PATCH
    my $fs = create_fs('c.txt' => 'to be removed');
    process_patch($patch, $fs->{open}, $fs->{write}, $fs->{remove});
    is_deeply($fs->{writes}, {}, 'no writes for delete');
    is_deeply($fs->{removals}, ['c.txt'], 'removes file');
}

# 4) identify_files_needed & identify_files_added
{
    my $patch = <<'PATCH';
*** Begin Patch
*** Update File: a.txt
*** Delete File: b.txt
*** Add File: c.txt
*** End Patch
PATCH
    my $needed = identify_files_needed($patch);
    my @need_sorted = sort @$needed;
    is_deeply(\@need_sorted, ['a.txt','b.txt'], 'identify needed');
    my $added = identify_files_added($patch);
    is_deeply($added, ['c.txt'], 'identify added');
}

# 5) update file with multiple chunks
{
    my $original = "line1\nline2\nline3\nline4";
    my $patch = <<'PATCH';
*** Begin Patch
*** Update File: multi.txt
@@
 line1
-line2
+line2 updated
 line3
+inserted line
 line4
*** End Patch
PATCH
    my $fs = create_fs('multi.txt' => $original);
    process_patch($patch, $fs->{open}, $fs->{write}, $fs->{remove});
    my $expected = "line1\nline2 updated\nline3\ninserted line\nline4";
    is_deeply($fs->{writes}, { 'multi.txt' => $expected }, 'multi-chunk update');
    is_deeply($fs->{removals}, [], 'no removals multi');
}

# 6) move file (rename)
{
    my $patch = <<'PATCH';
*** Begin Patch
*** Update File: old.txt
*** Move to: new.txt
@@
-old
+new
*** End Patch
PATCH
    my $fs = create_fs('old.txt' => 'old');
    process_patch($patch, $fs->{open}, $fs->{write}, $fs->{remove});
    is_deeply($fs->{writes}, { 'new.txt' => 'new' }, 'move write new');
    is_deeply($fs->{removals}, ['old.txt'], 'move remove old');
}

# 7) combined add, update, delete
{
    my $patch = <<'PATCH';
*** Begin Patch
*** Add File: added.txt
+added contents
*** Update File: upd.txt
@@
-old value
+new value
*** Delete File: del.txt
*** End Patch
PATCH
    my $fs = create_fs(
        'upd.txt' => 'old value',
        'del.txt' => 'delete me',
    );
    process_patch($patch, $fs->{open}, $fs->{write}, $fs->{remove});
    is_deeply(
        $fs->{writes},
        { 'added.txt' => 'added contents', 'upd.txt' => 'new value' },
        'combined writes'
    );
    is_deeply($fs->{removals}, ['del.txt'], 'combined remove');
}

# 8) readme edit
{
    my $original = <<'EOO';
#### Fix an issue

```sh
# First, copy an error
# Then, start codex with interactive mode
codex

# Or you can pass in via command line argument
codex "Fix this issue: $(pbpaste)"

# Or even as a task (it should use your current repo and branch)
codex -t "Fix this issue: $(pbpaste)"
```
EOO
    my $patch = <<'PATCH';
*** Begin Patch
*** Update File: README.md
@@
  codex -t "Fix this issue: $(pbpaste)"
  ```
+
+hello
*** End Patch
PATCH
    my $fs = create_fs('README.md' => $original);
    process_patch($patch, $fs->{open}, $fs->{write}, $fs->{remove});
    my $expected = <<'EOX';
#### Fix an issue

```sh
# First, copy an error
# Then, start codex with interactive mode
codex

# Or you can pass in via command line argument
codex "Fix this issue: $(pbpaste)"

# Or even as a task (it should use your current repo and branch)
codex -t "Fix this issue: $(pbpaste)"
```

hello
EOX
    chomp $expected;
    is_deeply($fs->{writes}, { 'README.md' => $expected }, 'readme edit');
    is_deeply($fs->{removals}, [], 'no removals in readme');
}