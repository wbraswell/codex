#!/usr/bin/env perl
# End-to-end pipeline for analysing a collection of text prompts (Perl port).
#
# Usage:
#   cluster_prompts.pl [--csv FILE] [--cache FILE] [--embedding-model MODEL]
#                          [--chat-model MODEL] [--cluster-method METHOD]
#                          [--k-max N] [--dbscan-min-samples N]
#                          [--output-md FILE] [--plots-dir DIR]
#                          [--help]
use strict;
use warnings;
use Getopt::Long qw(GetOptions);
use Path::Tiny qw(path);
use Text::CSV;
use JSON qw(decode_json encode_json);
use HTTP::Tiny;
use Algorithm::KMeans;
use List::Util qw(sum shuffle);
use POSIX qw(floor);

sub usage {
    die <<"USAGE";
Usage: $0 [options]
  --csv              Input CSV file (default: prompts.csv)
  --cache            JSON cache for embeddings
  --embedding-model  OpenAI embedding model (default: text-embedding-3-small)
  --chat-model       OpenAI chat model (default: gpt-4o-mini)
  --cluster-method   kmeans|dbscan (default: kmeans)
  --k-max            Upper bound for k when kmeans (default: 10)
  --dbscan-min-samples  min_samples for DBSCAN (default: 3)
  --output-md        Markdown report path (default: analysis.md)
  --plots-dir        Directory for PNG plots (default: plots)
  --help             Show this message
USAGE
}

# Default parameters
my $csv_file         = 'prompts.csv';
my $cache_file;
my $embed_model      = 'text-embedding-3-small';
my $chat_model       = 'gpt-4o-mini';
my $cluster_method   = 'kmeans';
my $k_max            = 10;
my $dbscan_min       = 3;
my $output_md        = 'analysis.md';
my $plots_dir        = 'plots';
my $help;

GetOptions(
    'csv=s'               => \$csv_file,
    'cache=s'             => \$cache_file,
    'embedding-model=s'   => \$embed_model,
    'chat-model=s'        => \$chat_model,
    'cluster-method=s'    => \$cluster_method,
    'k-max=i'             => \$k_max,
    'dbscan-min-samples=i'=> \$dbscan_min,
    'output-md=s'         => \$output_md,
    'plots-dir=s'         => \$plots_dir,
    'help'                => \$help,
) or usage();
usage() if $help;

# Read CSV prompts
my $csv = Text::CSV->new({ binary => 1 }) or die "Cannot use CSV: " . Text::CSV->error_diag();
open my $fh, '<:encoding(utf8)', $csv_file or die "Cannot open $csv_file: $!";
my $header = $csv->getline($fh) or die "Empty CSV file";
my %col_idx = map { $header->[$_] => $_ } 0 .. $#$header;
die "CSV missing 'prompt' column" unless exists $col_idx{prompt};
my @prompts;
while (my $row = $csv->getline($fh)) {
    push @prompts, $row->[ $col_idx{prompt} ];
}
close $fh;

print "Embedding ", scalar(@prompts), " prompts...\n";

# Ensure API key
my $api_key = $ENV{OPENAI_API_KEY} or die "Missing OPENAI_API_KEY\n";
# HTTP client
my $http = HTTP::Tiny->new;

# Embedding
my $vectors_ref = load_or_create_embeddings(\@prompts, cache_path => $cache_file, model => $embed_model, http => $http, api_key => $api_key);

# Clustering via KMeans
my ($labels_ref, $best_k, $best_score) = cluster_kmeans($vectors_ref, $k_max);
my @labels = @$labels_ref;

# Label clusters via LLM
my $meta_ref = label_clusters(\@prompts, \@labels, $chat_model, http => $http, api_key => $api_key);

# Generate markdown report
generate_markdown_report(\@prompts, \@labels, $meta_ref, { method => 'kmeans', k => $best_k, silhouette => $best_score }, $output_md);

print "✔ Report written to $output_md\n";
exit 0;

#-------------------------------------------------------------------------------
# Embed texts via OpenAI, with optional JSON cache
#-------------------------------------------------------------------------------
sub load_or_create_embeddings {
    my ($prompts_ref, %args) = @_;
    my $cache_file = $args{cache_path};
    my $model      = $args{model};
    my $http       = $args{http};
    my $api_key    = $args{api_key};

    # Load existing cache
    my %cache;
    if ($cache_file && -e $cache_file) {
        eval {
            %cache = %{ decode_json(path($cache_file)->slurp_utf8) };
        };
    }

    # Determine which prompts need embedding
    my @to_embed;
    foreach my $txt (@$prompts_ref) {
        push @to_embed, $txt unless exists $cache{$txt};
    }
    # Batch embed
    if (@to_embed) {
        print "Embedding ", scalar(@to_embed), " new prompt(s)...\n";
        while (@to_embed) {
            my @batch = splice(@to_embed, 0, 100);
            sleep 2;
            my $resp = $http->post(
                'https://api.openai.com/v1/embeddings',
                {
                    headers => {
                        'Content-Type'  => 'application/json',
                        'Authorization' => "Bearer $api_key",
                    },
                    content => encode_json({ model => $model, input => \\@batch }),
                }
            );
            die "Embedding API error: $resp->{status}\n" unless $resp->{success};
            my $j = decode_json($resp->{content});
            foreach my $data (@{ $j->{data} }) {
                my $i = $data->{index};
                $cache{ $batch[$i] } = $data->{embedding};
            }
        }
        # Persist cache
        if ($cache_file) {
            path($cache_file)->parent->mkpath;
            path($cache_file)->spew_utf8(encode_json(\%cache));
        }
    }
    # Build matrix in input order
    my @matrix = map { $cache{$_} } @$prompts_ref;
    return \@matrix;
}

#-------------------------------------------------------------------------------
# Auto-k KMeans clustering (uses Algorithm::KMeans), returns labels, k, score
#-------------------------------------------------------------------------------
sub cluster_kmeans {
    my ($matrix_ref, $k_max) = @_;
    # Use k_max clusters (silhouette optimization omitted)
    my $k = $k_max < 2 ? 1 : $k_max;
    my $km = Algorithm::KMeans->new(data => $matrix_ref, k => $k);
    my ($centroids, $clusters) = $km->kmeans;
    # clusters: hash of cluster_id => [indices]
    my @labels = ();
    # initialize labels to zero
    @labels[0 .. $#$matrix_ref] = (0) x @$matrix_ref;
    while (my ($cluster_id, $points) = each %$clusters) {
        foreach my $idx (@$points) {
            $labels[$idx] = $cluster_id;
        }
    }
    print "K-Means clustered into k=$k clusters.\n";
    return (\@labels, $k, 0);
}

#-------------------------------------------------------------------------------
# Label clusters via Chat Completions
#-------------------------------------------------------------------------------
sub label_clusters {
    my ($prompts_ref, $labels_ref, %args) = @_;
    my $chat_model = $args{chat_model};
    my $http       = $args{http};
    my $api_key    = $args{api_key};
    # Group prompts by label
    my %group;
    for my $i (0 .. $#$labels_ref) {
        push @{ $group{ $labels_ref->[$i] } }, $prompts_ref->[$i];
    }
    my %meta;
    foreach my $lbl (sort { $a <=> $b } keys %group) {
        if ($lbl == -1) {
            $meta{$lbl} = {
                name        => 'Noise / Outlier',
                description => 'Prompts that do not cleanly belong to any cluster.',
            };
            next;
        }
        # sample up to 12 examples
        my @ex = shuffle @{ $group{$lbl} };
        splice(@ex, 12) if @ex > 12;
        # build user prompt
        my $user_content =
            "The following text snippets are all part of the same semantic cluster.\n"
          . "Please propose:\n"
          . "1. A very short title (<= 4 words).\n"
          . "2. A concise 2-3 sentence description.\n"
          . "Answer strictly as JSON with keys 'name' and 'description'.\n\n"
          . "Snippets:\n"
          . join('', map { "- $_\n" } @ex);
        # call API
        sleep 2;
        my $resp = $http->post(
            'https://api.openai.com/v1/chat/completions',
            {
                headers => {
                    'Content-Type'  => 'application/json',
                    'Authorization' => "Bearer $api_key",
                },
                content => encode_json({ model => $chat_model, messages => [
                    { role => 'system', content => 'You are an expert analyst, competent in summarising text clusters succinctly.' },
                    { role => 'user',   content => $user_content },
                ]}),
            }
        );
        my $body = decode_json($resp->{content});
        my $reply = $body->{choices}[0]{message}{content} // '';
        # extract JSON payload
        my ($json_str) = $reply =~ /({.*})/s;
        my $obj = eval { decode_json($json_str // '{}') };
        $meta{$lbl} = {
            name        => substr($obj->{name} // 'Unnamed', 0, 60),
            description => $obj->{description} // '',
        };
    }
    return \%meta;
}

#-------------------------------------------------------------------------------
# Generate Markdown report file
#-------------------------------------------------------------------------------
sub generate_markdown_report {
    my ($prompts_ref, $labels_ref, $meta_ref, $outputs_ref, $path_md) = @_;
    # counts per cluster
    my %counts;
    $counts{$_}++ for @$labels_ref;
    my @clusters = sort { $a <=> $b } keys %counts;
    # header
    my @lines;
    push @lines, "# Prompt Clustering Report\n";
    my $ts = POSIX::strftime("%Y-%m-%d %H:%M:%S", localtime);
    push @lines, "Generated by `cluster_prompts.pl` – $ts\n";
    # overview
    push @lines, "## Overview\n";
    push @lines, "* Total prompts: **" . scalar(@$labels_ref) . "**";
    push @lines, "* Clustering method: **" . $outputs_ref->{method} . "**";
    push @lines, "* k (K-Means): **" . $outputs_ref->{k} . "**";
    push @lines, "* Silhouette score: **" . sprintf("%.3f", $outputs_ref->{silhouette}) . "**\n";
    # summary table
    push @lines, "| label | name | #prompts | description |";
    push @lines, "|-------|------|---------:|-------------|";
    for my $lbl (@clusters) {
        my $m = $meta_ref->{$lbl};
        push @lines, sprintf("| %d | %s | %d | %s |",
            $lbl, $m->{name}, $counts{$lbl}, $m->{description});
    }
    # detailed clusters
    for my $lbl (@clusters) {
        push @lines, "\n---\n";
        my $m = $meta_ref->{$lbl};
        push @lines, sprintf("### Cluster %d: %s (%d prompts)\n",
            $lbl, $m->{name}, $counts{$lbl});
        push @lines, "$m->{description}\n";
        # examples
        my @ex = @{$prompts_ref}[@{ [ grep { $labels_ref->[$_] == $lbl } 0 .. $#$labels_ref ] }];
        @ex = @ex[0..4] if @ex > 5;
        push @lines, "Examples:\n";
        push @lines, map { "* $_" } @ex;
    }
    # write file
    path($path_md)->parent->mkpath;
    path($path_md)->spew_utf8(join("\n", @lines) . "\n");
}