#!/usr/bin/perl
use strict;
use warnings;
use Getopt::Long;
use File::Find;
use File::Basename;

my $folder;
GetOptions("folder=s" => \$folder) or die "Usage: $0 --folder <folder_path>\n";

die "Usage: $0 --folder <folder_path>\n" unless defined $folder;

die "Error: Folder $folder does not exist.\n" unless -d $folder;

sub process_file {
    my $file = $File::Find::name;
    
    return unless -f $file;

    my $is_gz = ($file =~ /\.gz$/) ? 1 : 0;
    my $uncompressedFile = $file;
    $uncompressedFile =~ s/\.gz$// if $is_gz;
    
    my $fileType;
    if ($uncompressedFile =~ /\.gff$/) {
        $fileType = "gff";
    } elsif ($uncompressedFile =~ /\.vcf$/) {
        $fileType = "vcf";
    } elsif ($uncompressedFile =~ /\.bam$/) {
        $fileType = "bam";
    } elsif ($uncompressedFile =~ /\.bw$/) {
        $fileType = "bigwig";
    } else {
        print "Skipping unsupported file: $file\n";
        return;
    }

    my $indexFile;
    if ($fileType eq "gff" || $fileType eq "vcf") {
        $indexFile = "${uncompressedFile}.gz.tbi";
    } elsif ($fileType eq "bam") {
        $indexFile = "${uncompressedFile}.bai";
    } elsif ($fileType eq "bigwig") {
        # BigWig files don't require an index, so we skip the check
        print "BigWig (.bw) files do not require sorting, compression, or indexing.\n";
        return;
    }

    if (-e $indexFile) {
        print "Index file already exists for $file ($indexFile). Skipping processing.\n";
        return;
    }

    if ($is_gz) {
        my $gunzipCmd = "gunzip -c $file > $uncompressedFile";
        print "Running: $gunzipCmd\n";
        system($gunzipCmd) == 0 or die "Error executing: $gunzipCmd\n";
    }

    my @commands;
    if ($fileType eq "gff") {
        push @commands, "grep -v '^#' $uncompressedFile | sort -k1,1 -k4,4n > ${uncompressedFile}.sorted";
        push @commands, "bgzip -c ${uncompressedFile}.sorted > ${uncompressedFile}.gz";
        push @commands, "tabix -p gff ${uncompressedFile}.gz";
        push @commands, "rm ${uncompressedFile}.sorted";
    } 
    elsif ($fileType eq "vcf") {
        push @commands, "bcftools sort $uncompressedFile -o ${uncompressedFile}.sorted";
        push @commands, "bgzip -c ${uncompressedFile}.sorted > ${uncompressedFile}.gz";
        push @commands, "tabix -p vcf ${uncompressedFile}.gz";
        push @commands, "rm ${uncompressedFile}.sorted";
    } 
    elsif ($fileType eq "bam") {
        push @commands, "samtools sort -o ${uncompressedFile}.sorted.bam $uncompressedFile";
        push @commands, "mv ${uncompressedFile}.sorted.bam ${uncompressedFile}";
        push @commands, "samtools index ${uncompressedFile}";
    } 

    for my $cmd (@commands) {
        print "Running: $cmd\n";
        system($cmd) == 0 or die "Error executing: $cmd\n";
    }

    print "Processing of $fileType file completed successfully: $file\n";
}

find(\&process_file, $folder);

