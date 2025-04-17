package Codex::Config;
use strict;
use warnings;
use Exporter 'import';
use JSON;
use YAML::XS qw(Load Dump);
use File::Spec;
use File::Basename qw(dirname);
use File::Path qw(make_path);
use Cwd qw(getcwd);

our @EXPORT_OK = qw(
    load_config
    save_config
);

use constant {
    DEFAULT_AGENTIC_MODEL      => 'o4-mini',
    DEFAULT_FULL_CONTEXT_MODEL => 'gpt-4.1',
    DEFAULT_INSTRUCTIONS       => '',
    PROJECT_DOC_MAX_BYTES      => 32 * 1024,
};

use constant {
    CONFIG_DIR            => File::Spec->catdir($ENV{HOME} || '', '.codex'),
    CONFIG_JSON_FILEPATH  => File::Spec->catfile(CONFIG_DIR, 'config.json'),
    CONFIG_YAML_FILEPATH  => File::Spec->catfile(CONFIG_DIR, 'config.yaml'),
    CONFIG_YML_FILEPATH   => File::Spec->catfile(CONFIG_DIR, 'config.yml'),
    CONFIG_FILEPATH       => CONFIG_JSON_FILEPATH,
    INSTRUCTIONS_FILEPATH => File::Spec->catfile(CONFIG_DIR, 'instructions.md'),
};

use constant EMPTY_STORED_CONFIG => { model => '' };
use constant EMPTY_CONFIG_JSON   => JSON->new->canonical->pretty->encode({ model => '' });

our @PROJECT_DOC_FILENAMES = qw(codex.md .codex.md CODEX.md);

=head1 NAME

Codex::Config - Load and save CLI configuration and project docs

=cut

sub discover_project_doc_path {
    my ($start_dir) = @_;
    my $cwd = File::Spec->rel2abs($start_dir // '.');
    for my $name (@PROJECT_DOC_FILENAMES) {
        my $path = File::Spec->catfile($cwd, $name);
        return $path if -e $path;
    }
    my $dir = $cwd;
    while (1) {
        my $gitdir = File::Spec->catdir($dir, '.git');
        if (-d $gitdir) {
            for my $name (@PROJECT_DOC_FILENAMES) {
                my $cand = File::Spec->catfile($dir, $name);
                return $cand if -e $cand;
            }
            return;
        }
        my $parent = dirname($dir);
        last if $parent eq $dir;
        $dir = $parent;
    }
    return;
}

=head2 load_project_doc(cwd, explicit_path)

Load and truncate (if necessary) the project documentation file.
=cut
sub load_project_doc {
    my ($cwd, $explicit) = @_;
    my $filepath;
    if ($explicit) {
        $filepath = File::Spec->rel2abs($explicit, $cwd);
        unless (-e $filepath) {
            warn "codex: project doc not found at $filepath";
            return '';
        }
    } else {
        $filepath = discover_project_doc_path($cwd);
        return '' unless $filepath;
    }
    my $content = '';
    if (open my $fh, '<:encoding(UTF-8)', $filepath) {
        local $/;
        $content = <$fh>;
        close $fh;
    }
    if (length($content) > PROJECT_DOC_MAX_BYTES) {
        warn "codex: project doc '$filepath' exceeds " . PROJECT_DOC_MAX_BYTES . " bytes – truncating.";
        $content = substr($content, 0, PROJECT_DOC_MAX_BYTES);
    }
    return $content;
}

=head2 load_config(config_path?, instructions_path?, options?)

Load CLI configuration, defaulting to JSON or YAML, and merge in project docs.
=cut
sub load_config {
    my ($config_path, $instructions_path, $options) = @_;
    $config_path      //= CONFIG_FILEPATH;
    $instructions_path//= INSTRUCTIONS_FILEPATH;
    $options          ||= {};

    my $actual = $config_path;
    unless (-e $actual) {
        if ($config_path eq CONFIG_FILEPATH) {
            if (-e CONFIG_YAML_FILEPATH) { $actual = CONFIG_YAML_FILEPATH }
            elsif (-e CONFIG_YML_FILEPATH) { $actual = CONFIG_YML_FILEPATH }
        }
    }

    my $stored = {};
    if (-e $actual) {
        local $/;
        open my $cfh, '<:encoding(UTF-8)', $actual or die $!;
        my $raw = <$cfh>;
        close $cfh;
        if ($actual =~ /\.ya?ml$/i) {
            eval { $stored = Load($raw) || {} };
        } else {
            eval { $stored = JSON->new->utf8->decode($raw) || {} };
        }
        $stored = {} if $@;
    }

    my $user_instructions = '';
    if (-e $instructions_path) {
        local $/;
        open my $ifh, '<:encoding(UTF-8)', $instructions_path or die $!;
        $user_instructions = <$ifh>;
        close $ifh;
    } else {
        $user_instructions = DEFAULT_INSTRUCTIONS;
    }

    my $project_doc = '';
    if (!$options->{disableProjectDoc} && !($ENV{CODEX_DISABLE_PROJECT_DOC}//'') eq '1') {
        my $cwd = $options->{cwd} // getcwd();
        $project_doc = load_project_doc($cwd, $options->{projectDocPath});
    }

    my @parts = grep { defined && /\S/ } ($user_instructions, $project_doc);
    my $combined = join "\n\n--- project-doc ---\n\n", @parts;

    my $stored_model = $stored->{model} // '';
    $stored_model =~ s/^\s+|\s+\$//g;
    $stored_model = undef if $stored_model eq '';

    my $model = $stored_model // ($options->{isFullContext} ? DEFAULT_FULL_CONTEXT_MODEL : DEFAULT_AGENTIC_MODEL);

    my %config = (
        model        => $model,
        instructions => $combined,
    );
    $config{memory}           = $stored->{memory} if exists $stored->{memory};
    $config{fullAutoErrorMode}= $stored->{fullAutoErrorMode} if exists $stored->{fullAutoErrorMode};

    eval {
        unless (-e $actual) {
            my $dir = dirname($actual);
            make_path($dir) unless -d $dir;
            if ($actual =~ /\.ya?ml$/i) {
                open my $wfh, '>:encoding(UTF-8)', $actual or die $!;
                print $wfh Dump(EMPTY_STORED_CONFIG);
                close $wfh;
            } else {
                open my $wfh, '>:encoding(UTF-8)', $actual or die $!;
                print $wfh EMPTY_CONFIG_JSON;
                close $wfh;
            }
        }
        unless (-e $instructions_path) {
            my $idir = dirname($instructions_path);
            make_path($idir) unless -d $idir;
            open my $ifh2, '>:encoding(UTF-8)', $instructions_path or die $!;
            print $ifh2 $user_instructions;
            close $ifh2;
        }
    };

    return \%config;
}

=head2 save_config(config_ref, config_path?, instructions_path?)

Persist model and instructions to disk, respecting JSON/YAML format.
=cut
sub save_config {
    my ($cfg, $config_path, $instructions_path) = @_;
    $config_path      //= CONFIG_FILEPATH;
    $instructions_path//= INSTRUCTIONS_FILEPATH;

    my $target = $config_path;
    unless (-e $config_path) {
        if ($config_path eq CONFIG_FILEPATH) {
            if (-e CONFIG_YAML_FILEPATH) { $target = CONFIG_YAML_FILEPATH }
            elsif (-e CONFIG_YML_FILEPATH) { $target = CONFIG_YML_FILEPATH }
        }
    }
    my $dir = dirname($target);
    make_path($dir) unless -d $dir;

    if ($target =~ /\.ya?ml$/i) {
        open my $fh, '>:encoding(UTF-8)', $target or die $!;
        print $fh Dump({ model => $cfg->{model} });
        close $fh;
    } else {
        open my $fh, '>:encoding(UTF-8)', $target or die $!;
        print $fh JSON->new->canonical->pretty->encode({ model => $cfg->{model} });
        close $fh;
    }

    my $idir = dirname($instructions_path);
    make_path($idir) unless -d $idir;
    open my $ifh, '>:encoding(UTF-8)', $instructions_path or die $!;
    print $ifh $cfg->{instructions};
    close $ifh;
}

1;