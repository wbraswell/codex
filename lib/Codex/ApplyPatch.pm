package Codex::ApplyPatch;
use strict;
use warnings;
use Exporter 'import';
use Perl::Types qw(string arrayref hashref);

our @EXPORT_OK = qw(
    ActionType
    apply_commit
    assemble_changes
    DiffError
    identify_files_added
    identify_files_needed
    load_files
    patch_to_commit
    process_patch
    text_to_patch
);

# Constants for action types
sub ActionType { { ADD => 'add', DELETE => 'delete', UPDATE => 'update' } }

# Placeholder for DiffError class
sub DiffError { 'Codex::ApplyPatch::DiffError' }

# Assemble a commit from original and updated file content maps
sub assemble_changes {
    my ($orig, $updated) = @_;
    my %changes;
    for my $path (keys %$updated) {
        if (exists $orig->{$path}) {
            $changes{$path} = { type => 'update', old_content => $orig->{$path}, new_content => $updated->{$path} };
        } else {
            $changes{$path} = { type => 'add', new_content => $updated->{$path} };
        }
    }
    for my $path (grep { !exists $updated->{$_} } keys %$orig) {
        $changes{$path} = { type => 'delete', old_content => $orig->{$path} };
    }
    return { changes => \%changes };
}

# Parse patch text into action structures
sub text_to_patch {
    my ($patch_text) = @_;
    chomp $patch_text;
    my @lines = split /\n/, $patch_text;
    die "Invalid patch" unless @lines && $lines[0] eq '*** Begin Patch';
    die "Invalid patch" unless $lines[-1] eq '*** End Patch';
    shift @lines;
    pop @lines;
    my %actions;
    my $i = 0;
    while ($i <= $#lines) {
        my $line = $lines[$i++];
        if ($line =~ /^\*\*\* Add File: (.+)$/) {
            my $path = $1;
            my @content;
            while ($i <= $#lines && $lines[$i] !~ /^\*\*\* /) {
                if ($lines[$i] =~ /^\+(.*)$/) { push @content, $1 }
                $i++;
            }
            $actions{$path} = { type => 'add', new_file => join("\n", @content) };
        }
        elsif ($line =~ /^\*\*\* Delete File: (.+)$/) {
            my $path = $1;
            $actions{$path} = { type => 'delete' };
        }
        elsif ($line =~ /^\*\*\* Update File: (.+)$/) {
            my $path = $1;
            my $move_path;
            if ($i <= $#lines && $lines[$i] =~ /^\*\*\* Move to: (.+)$/) {
                ($move_path) = $lines[$i] =~ /^\*\*\* Move to: (.+)$/;
                $i++;
            }
            my @patch_lines;
            while ($i <= $#lines && $lines[$i] !~ /^\*\*\* /) {
                push @patch_lines, $lines[$i++];
            }
            $actions{$path} = { type => 'update', move_path => $move_path, patch_lines => \@patch_lines };
        }
        elsif ($line =~ /^\*\*\* End Patch/) {
            last;
        }
    }
    return { actions => \%actions };
}

# Identify which files need to be loaded (update or delete)
sub identify_files_needed {
    my ($patch_text) = @_;
    my $p = text_to_patch($patch_text);
    my @needed = grep { my $t = $p->{actions}{$_}{type}; $t eq 'update' || $t eq 'delete' } keys %{ $p->{actions} };
    return \@needed;
}

# Identify which files are added
sub identify_files_added {
    my ($patch_text) = @_;
    my $p = text_to_patch($patch_text);
    my @added = grep { $p->{actions}{$_}{type} eq 'add' } keys %{ $p->{actions} };
    return \@added;
}

# Load file contents via provided open_fn
sub load_files {
    my ($files, $open_fn) = @_;
    my %map;
    for my $p (@$files) {
        $map{$p} = $open_fn->($p);
    }
    return \%map;
}

# Apply a series of patches to an in-memory file system
sub process_patch {
    my ($patch_text, $open_fn, $write_fn, $remove_fn) = @_;
    my $p = text_to_patch($patch_text);
    for my $path (keys %{ $p->{actions} }) {
        my $act = $p->{actions}{$path};
        if ($act->{type} eq 'add') {
            $write_fn->($path, $act->{new_file});
        }
        elsif ($act->{type} eq 'delete') {
            $remove_fn->($path);
        }
        elsif ($act->{type} eq 'update') {
            my $old = $open_fn->($path);
            # parse patch lines into actions
            my @parsed;
            for my $pline (@{ $act->{patch_lines} }) {
                next if $pline =~ /^@@/;
                my $c = substr($pline, 0, 1);
                my $text = substr($pline, 1);
                if ($c eq '+') {
                    push @parsed, { type => 'add', text => $text };
                } elsif ($c eq '-') {
                    push @parsed, { type => 'delete', text => $text };
                } elsif ($c eq ' ') {
                    push @parsed, { type => 'context', text => $text };
                }
            }
            my $new;
            # if only additions (no deletes), perform simple insert
            # if only additions (no deletes), perform simple insert
            # if only additions (no deletes), perform simple insert
            if ( (grep { $_->{type} eq 'add' } @parsed) && !(grep { $_->{type} eq 'delete' } @parsed) ) {
                $new = _simple_insert($old, \@parsed);
            } else {
                $new = apply_patch_lines($old, $act->{patch_lines});
            }
            if ($act->{move_path}) {
                $write_fn->($act->{move_path}, $new);
                $remove_fn->($path);
            } else {
                $write_fn->($path, $new);
            }
        }
    }
    return 'Done!';
}

# Helper to apply patch lines to old content
sub apply_patch_lines {
    my ($old_content, $patch_lines) = @_;
    my @old_lines = split /\n/, $old_content;
    my @new_lines;
    my $i_old = 0;
    for my $pline (@$patch_lines) {
        next if $pline =~ /^@@/;
        if ($pline =~ /^\+(.*)$/) {
            push @new_lines, $1;
        } elsif ($pline =~ /^-(.*)$/) {
            $i_old++;
        } elsif ($pline =~ /^\s?(.*)$/) {
            my $content = $1;
            $i_old++;
            push @new_lines, $content;
        }
    }
    push @new_lines, @old_lines[$i_old .. $#old_lines] if $i_old <= $#old_lines;
    return join("\n", @new_lines);
}

# Simple insert for patches with only additions: insert added lines after last context match
sub _simple_insert {
    my ($old_text, $actions) = @_;
    my @old = split /\n/, $old_text;
    # find context texts before additions
    my $first_add;
    my @adds;
    for my $a (@$actions) {
        if ($a->{type} eq 'add') {
            $first_add = $a; last;
        }
    }
    @adds = map { $_->{text} } grep { $_->{type} eq 'add' } @$actions;
    # find last context before first add
    my $ctx_text;
    for my $a (@$actions) {
        if ($a->{type} eq 'context') { $ctx_text = $a->{text} }
        last if $a->{type} eq 'add';
    }
    # locate insertion index after context line
    my $pos = -1;
    if (defined $ctx_text) {
        for my $i (0 .. $#old) {
            $pos = $i if $old[$i] eq $ctx_text;
        }
    }
    $pos = $#old if $pos < 0;
    splice(@old, $pos + 1, 0, @adds);
    return join("\n", @old);
}

# Stubs for unused functions
sub patch_to_commit { die 'Not implemented' }
sub apply_commit    { die 'Not implemented' }

1;