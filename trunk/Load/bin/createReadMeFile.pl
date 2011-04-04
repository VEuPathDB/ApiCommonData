#!/usr/bin/perl
use strict;

use Getopt::Long;
use Data::Dumper;

my ($baseDir,$verbose,$outputFile);
&GetOptions("verbose!" => \$verbose,
	    "baseDir=s" => \$baseDir,
	    "outputFile=s" => \$outputFile);

die "Must provide a baseDir\n" unless ($baseDir);

print "Process files recursively in $baseDir\n" if $verbose;

die "$baseDir doesn't exist\n"  unless (-w $baseDir);

my @resideFiles=process_files ($baseDir);

print Dumper (\@resideFiles) if $verbose;

my $cmd= "cat " . join (' ', grep {(/\.desc$/)} @resideFiles) . "> $outputFile";

system ($cmd) || print $!;

print STDERR "$cmd\n" ;

sub process_files {

    my $path = shift;

    opendir (DIR, $path)
        or die "Unable to open $path: $!";

    # LIST = map(EXP, grep(EXP, readdir()))
    my @files =
        map { $path . '/' . $_ }
        grep { !/^\.{1,2}$/ }
        readdir (DIR);

    closedir (DIR);

    for (@files) {
        if (-d $_) {
            push @files, process_files ($_);

        } else {
        }
    }
    return @files;
}


1;
