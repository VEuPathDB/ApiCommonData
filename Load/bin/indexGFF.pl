#!/usr/bin/perl
use strict;
use warnings;
use Getopt::Long;

# Parse command-line arguments
my $gffFile;
GetOptions("gff=s" => \$gffFile) or die "Usage: $0 --gff <gff_file>\n";

# Check if GFF file is provided
die "Usage: $0 --gff <gff_file>\n" unless defined $gffFile;

# Define commands
my $createTmpCmd = "mv $gffFile ${gffFile}.tmp";
my $sortGffCmd   = "grep -v '^#' ${gffFile}.tmp | sort -k1,1 -k4,4n > $gffFile";
my $bgzipCmd     = "bgzip $gffFile";
my $tabixCmd     = "tabix -p gff ${gffFile}.gz";
my $rmTmpCmd     = "rm ${gffFile}.tmp";

# Execute commands
for my $cmd ($createTmpCmd, $sortGffCmd, $bgzipCmd, $tabixCmd, $rmTmpCmd) {
    print "Running: $cmd\n";
    system($cmd) == 0 or die "Error executing: $cmd\n";
}

print "Processing completed successfully.\n";

