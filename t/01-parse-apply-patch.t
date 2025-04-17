use strict;
use warnings;
use Test::More tests => 4;
use lib qw(../lib);
use Codex::ParseApplyPatch qw(parse_apply_patch);

# Valid patch: create, update, delete
my $patch = <<'PATCH';
*** Begin Patch
*** Add File: created.txt
+hello
+world
*** Update File: updated.txt
@@
-old
+new
*** Delete File: removed.txt
*** End Patch
PATCH

my $ops = parse_apply_patch($patch);
ok(defined $ops, 'Parsed valid patch');
is(scalar @$ops, 3, 'Three operations');

is_deeply($ops->[0],
    { type => 'create', path => 'created.txt', content => "hello\nworld" },
    'Create op');

# Invalid patch: missing prefix
my $invalid = <<'PATCH';
*** Add File: foo.txt
+bar
*** End Patch
PATCH

ok(!defined parse_apply_patch($invalid), 'Invalid patch returns undef');