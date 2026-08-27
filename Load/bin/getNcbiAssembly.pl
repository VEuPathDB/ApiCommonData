#!/usr/bin/env perl

use strict;
use warnings;

use Getopt::Long qw(GetOptions);
use File::Basename qw(basename);
use File::Path qw(make_path);
use HTTP::Tiny;

my (
    $organism_name,
    $accession_number,
    $file_types_argument,
    $output_dir,
    $help,
);

$output_dir = '.';

GetOptions(
    'organismName=s'    => \$organism_name,
    'accessionNumber=s' => \$accession_number,
    'fileType=s'        => \$file_types_argument,
    'outputDir=s'       => \$output_dir,
    'help|h'            => \$help,
) or usage(1);

usage(0) if $help;

validate_command_line_options();

download_ncbi_assembly_files(
    organism_name   => $organism_name,
    accession       => $accession_number,
    file_types      => $file_types_argument,
    output_dir      => $output_dir,
);


sub download_ncbi_assembly_files {
    my (%args) = @_;

    my $organism  = $args{organism_name};
    my $accession = uc $args{accession};
    my $output    = $args{output_dir};

    my @file_types = parse_file_types($args{file_types});

    my ($database, $assembly_summary_url);

    if ($accession =~ /^GCA_\d+\.\d+$/) {
        $database = 'GenBank';

        $assembly_summary_url =
            'https://ftp.ncbi.nlm.nih.gov/genomes/genbank/'
            . 'assembly_summary_genbank.txt';
    }
    elsif ($accession =~ /^GCF_\d+\.\d+$/) {
        $database = 'RefSeq';

        $assembly_summary_url =
            'https://ftp.ncbi.nlm.nih.gov/genomes/refseq/'
            . 'assembly_summary_refseq.txt';
    }
    else {
        die <<"ERROR";
ERROR: Invalid assembly accession '$accession'.

The accession must include a version number and look like:

  GCA_026262505.2
  GCF_000005845.2

ERROR
    }

    create_output_directory($output);

    print STDERR "Database:       $database\n";
    print STDERR "Organism:       $organism\n";
    print STDERR "Accession:      $accession\n";
    print STDERR "File type(s):   " . join(', ', @file_types) . "\n";
    print STDERR "Output folder:  $output\n";
    print STDERR "Reading NCBI assembly summary...\n";

    my $assembly_record = find_assembly_record(
        accession           => $accession,
        assembly_summary_url => $assembly_summary_url,
    );

    compare_organism_names(
        requested_organism => $organism,
        ncbi_organism      => $assembly_record->{organism_name},
        accession         => $accession,
    );

    my $ftp_path = $assembly_record->{ftp_path};

    $ftp_path =~ s{^ftp://}{https://}i;

    my $assembly_directory = basename($ftp_path);

    print STDERR "Assembly:       $assembly_directory\n";
    print STDERR "NCBI path:      $ftp_path\n\n";

    my %file_suffix = file_type_suffixes();

    my $download_count = 0;
    my @failed_files;

    for my $file_type (@file_types) {
        my $suffix = $file_suffix{$file_type};

        my $filename;
        my $url;

        if ($file_type eq 'md5') {
            $filename = 'md5checksums.txt';
            $url      = "$ftp_path/$filename";
        }
        else {
            $filename = $assembly_directory . $suffix;
            $url      = "$ftp_path/$filename";
        }

        print STDERR "Downloading $file_type:\n";
        print STDERR "  $url\n";

        my $success = download_with_wget(
            url        => $url,
            output_dir => $output,
        );

        if ($success) {
            $download_count++;

            print STDERR "Downloaded:\n";
            print STDERR "  $output/$filename\n\n";
        }
        else {
            push @failed_files, {
                file_type => $file_type,
                url       => $url,
            };

            warn "WARNING: Could not download file type "
                . "'$file_type'.\n\n";
        }
    }

    print STDERR "Download summary:\n";
    print STDERR "  Successful: $download_count\n";
    print STDERR "  Failed:     " . scalar(@failed_files) . "\n";

    if (@failed_files) {
        print STDERR "\nFiles that could not be downloaded:\n";

        for my $failure (@failed_files) {
            print STDERR sprintf(
                "  %-10s %s\n",
                $failure->{file_type},
                $failure->{url},
            );
        }

        die "\nERROR: One or more requested files were not downloaded.\n";
    }

    print STDERR "\nAll requested files were downloaded successfully.\n";
}


sub find_assembly_record {
    my (%args) = @_;

    my $accession = $args{accession};
    my $summary_url = $args{assembly_summary_url};

    my $http = HTTP::Tiny->new(
        timeout => 180,
        agent   => 'ncbi-assembly-downloader/1.0',
    );

    my $response = $http->get($summary_url);

    unless ($response->{success}) {
        die sprintf(
            "ERROR: Could not download the NCBI assembly summary.\n"
            . "URL: %s\n"
            . "HTTP status: %s\n"
            . "Reason: %s\n",
            $summary_url,
            $response->{status} // 'unknown',
            $response->{reason} // 'unknown',
        );
    }

    for my $line (split /\n/, $response->{content}) {
        next if $line =~ /^#/;
        next if $line =~ /^\s*$/;

        my @fields = split /\t/, $line, -1;

        # Important assembly_summary columns:
        #
        # Column 1:  assembly_accession
        # Column 8:  organism_name
        # Column 20: ftp_path
        next unless @fields >= 20;

        my $found_accession = uc $fields[0];

        next unless $found_accession eq $accession;

        my $organism_name = $fields[7];
        my $ftp_path      = $fields[19];

        if (
            !defined $ftp_path
            || $ftp_path eq ''
            || lc($ftp_path) eq 'na'
        ) {
            die "ERROR: NCBI does not provide an assembly FTP path "
                . "for $accession.\n";
        }

        return {
            accession     => $found_accession,
            organism_name => $organism_name,
            ftp_path      => $ftp_path,
        };
    }

    die "ERROR: Assembly accession $accession was not found in:\n"
        . "  $summary_url\n";
}


sub download_with_wget {
    my (%args) = @_;

    my $url        = $args{url};
    my $output_dir = $args{output_dir};

    my @command = (
        'wget',
        '--continue',
        '--no-verbose',
        '--directory-prefix',
        $output_dir,
        $url,
    );

    my $status = system(@command);

    if ($status == -1) {
        die "ERROR: Could not run wget: $!\n";
    }

    if ($status & 127) {
        my $signal = $status & 127;

        die "ERROR: wget was terminated by signal $signal.\n";
    }

    my $exit_code = $status >> 8;

    return $exit_code == 0;
}


sub parse_file_types {
    my ($file_types_argument) = @_;

    my %valid_suffix = file_type_suffixes();

    my @requested_types =
        split /,/, lc($file_types_argument);

    my @file_types;
    my %already_seen;

    for my $file_type (@requested_types) {
        $file_type =~ s/^\s+//;
        $file_type =~ s/\s+$//;

        next if $file_type eq '';

        # Accept a few convenient aliases.
        $file_type = 'fasta'   if $file_type eq 'fna';
        $file_type = 'protein' if $file_type eq 'faa';
        $file_type = 'gff'     if $file_type eq 'gff3';
        $file_type = 'gbff'    if $file_type eq 'gbk';

        unless (exists $valid_suffix{$file_type}) {
            my $valid_values = join(
                ', ',
                sort keys %valid_suffix,
            );

            die "ERROR: Unsupported --fileType value "
                . "'$file_type'.\n"
                . "Supported values are:\n"
                . "  $valid_values\n";
        }

        next if $already_seen{$file_type}++;

        push @file_types, $file_type;
    }

    unless (@file_types) {
        die "ERROR: No valid file types were supplied.\n";
    }

    return @file_types;
}


sub file_type_suffixes {
    return (
        gbff    => '_genomic.gbff.gz',
        gff     => '_genomic.gff.gz',
        fasta   => '_genomic.fna.gz',
        cds     => '_cds_from_genomic.fna.gz',
        rna     => '_rna_from_genomic.fna.gz',
        protein => '_protein.faa.gz',
        report  => '_assembly_report.txt',
        stats   => '_assembly_stats.txt',
        md5     => 'md5checksums.txt',
    );
}


sub compare_organism_names {
    my (%args) = @_;

    my $requested = $args{requested_organism};
    my $ncbi_name = $args{ncbi_organism};
    my $accession = $args{accession};

    return
        if normalize_organism_name($requested)
        eq normalize_organism_name($ncbi_name);

    warn sprintf(
        "WARNING: The supplied organism name does not exactly match "
        . "the NCBI assembly record.\n"
        . "  Accession:       %s\n"
        . "  Supplied name:   %s\n"
        . "  NCBI name:       %s\n\n",
        $accession,
        $requested,
        $ncbi_name,
    );
}


sub normalize_organism_name {
    my ($name) = @_;

    $name = '' unless defined $name;

    $name =~ s/^\s+//;
    $name =~ s/\s+$//;
    $name =~ s/\s+/ /g;

    return lc $name;
}


sub create_output_directory {
    my ($directory) = @_;

    return if -d $directory;

    eval {
        make_path($directory);
    };

    if ($@ || !-d $directory) {
        die "ERROR: Could not create output directory "
            . "'$directory': $@\n";
    }
}


sub validate_command_line_options {
    unless (
        defined $organism_name
        && $organism_name ne ''
    ) {
        die "ERROR: --organismName is required.\n\n"
            . usage_text();
    }

    unless (
        defined $accession_number
        && $accession_number ne ''
    ) {
        die "ERROR: --accessionNumber is required.\n\n"
            . usage_text();
    }

    unless (
        defined $file_types_argument
        && $file_types_argument ne ''
    ) {
        die "ERROR: --fileType is required.\n\n"
            . usage_text();
    }

    unless (
        defined $output_dir
        && $output_dir ne ''
    ) {
        die "ERROR: --outputDir cannot be empty.\n";
    }
}


sub usage {
    my ($exit_code) = @_;

    my $handle = $exit_code == 0 ? *STDOUT : *STDERR;

    print {$handle} usage_text();

    exit $exit_code;
}


sub usage_text {
    return <<"USAGE";
Usage:
  getNcbiAssembly.pl \\
    --organismName "scientific name" \\
    --accessionNumber GCA_or_GCF_accession \\
    --fileType type1,type2,type3 \\
    [--outputDir directory]

Required options:
  --organismName
      Organism scientific name.

  --accessionNumber
      Versioned NCBI assembly accession.

      GCA accessions use the GenBank assembly summary.
      GCF accessions use the RefSeq assembly summary.

  --fileType
      One or more comma-separated file types.

Supported file types:
  gbff
      GenBank flat file:
      *_genomic.gbff.gz

  gff
      GFF3 annotation:
      *_genomic.gff.gz

  fasta
      Genomic FASTA:
      *_genomic.fna.gz

  cds
      CDS FASTA:
      *_cds_from_genomic.fna.gz

  rna
      RNA FASTA:
      *_rna_from_genomic.fna.gz

  protein
      Protein FASTA:
      *_protein.faa.gz

  report
      Assembly report:
      *_assembly_report.txt

  stats
      Assembly statistics:
      *_assembly_stats.txt

  md5
      NCBI checksum file:
      md5checksums.txt

Optional options:
  --outputDir
      Directory into which files will be downloaded.
      Default: current directory

  --help, -h
      Display this help message.

Examples:

  Download GBFF, GFF3, and protein FASTA:

    getNcbiAssembly.pl \\
      --organismName "Trichomonas vaginalis" \\
      --accessionNumber GCA_026262505.2 \\
      --fileType gbff,gff,protein

  Download genome FASTA and GFF3 into ./downloads:

    getNcbiAssembly.pl \\
      --organismName "Trichomonas vaginalis" \\
      --accessionNumber GCA_026262505.2 \\
      --fileType fasta,gff \\
      --outputDir ./downloads

  Download files from a RefSeq assembly:

    getNcbiAssembly.pl \\
      --organismName "Escherichia coli" \\
      --accessionNumber GCF_000005845.2 \\
      --fileType gbff,gff,fasta,protein

USAGE
}

