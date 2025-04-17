use strict;
use warnings;
use Data::Dumper;
use lib 'lib';
use Codex::ApplyPatch qw(process_patch);
my $patch = <<'PATCH';
*** Begin Patch
*** Update File: a.txt
@@
-hello
+hello world
*** End Patch
PATCH
my %files = ('a.txt' => 'hello');
my %writes;
my @removals;
my $open = sub{ return $files{shift()}; };
my $write = sub{ my($p,$c)=@_; $writes{$p}=$c; };
my $remove = sub{ push @removals, shift(); };
my $res = process_patch($patch, $open, $write, $remove);
print "Result: $res\n";
print "WRITES: ", Dumper(\%writes);
print "REMOVALS: ", Dumper(\@removals);
