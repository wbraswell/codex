#!/usr/bin/env perl
"""End-to-end pipeline for analysing a collection of text prompts (Perl port).

Usage:
  cluster_prompts.pl [--csv FILE] [--cache FILE] [--embedding-model MODEL]
                         [--chat-model MODEL] [--cluster-method METHOD]
                         [--k-max N] [--dbscan-min-samples N]
                         [--output-md FILE] [--plots-dir DIR]
                         [--help]
"""
use strict;
use warnings;
use Getopt::Long qw(GetOptions);
use Path::Tiny qw(path);
use Text::CSV;
use JSON;

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
# TODO: implement embedding, clustering, labeling, plotting, report generation

print "✔ Report would be written to $output_md, plots to $plots_dir/\n";
exit 0;