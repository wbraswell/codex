use strict;
use warnings;
use Data::Dumper;
use lib 'lib';
use Codex::ApplyPatch qw(process_patch);
my $original = <<'EOO';
#### Fix an issue

```sh
# First, copy an error
# Then, start codex with interactive mode
codex

# Or you can pass in via command line argument
codex "Fix this issue: \\$(pbpaste)"

# Or even as a task (it should use your current repo and branch)
codex -t "Fix this issue: \\$(pbpaste)"
```
EOO
my $patch = <<'PATCH';
*** Begin Patch
*** Update File: README.md
@@
  codex -t "Fix this issue: \\$(pbpaste)"
  ```
+
+hello
*** End Patch
PATCH
my %files = ('README.md' => $original);
my %writes;
my @removals;
my $open = sub { my ($p) = @_; return $files{$p}; };
my $write = sub { my ($p, $c) = @_; $writes{$p} = $c; };
my $remove = sub { my ($p) = @_; push @removals, $p; };
my $res = process_patch($patch, $open, $write, $remove);
print "Result: $res\n";
print "WRITES:\n";
print Dumper(\%writes);
print "REMOVALS:\n";
print Dumper(\@removals);
