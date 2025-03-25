#!/usr/bin/perl
use strict;
use warnings;
use File::Copy;

die "Usage: $0 <copyFromDir> <copyToDir>\n" unless @ARGV == 2;
my ($copyFromDir, $copyToDir) = @ARGV;
my $modified_from_dir = $copyFromDir;
$modified_from_dir =~ s#/gff(1|2|3)/#/gff/#g;
die "Error: Source directory $modified_from_dir does not exist!\n" unless -d $modified_from_dir;
my $cp_command = "cp -aL $modified_from_dir $copyToDir";
system($cp_command) == 0 or die "Error executing command: $cp_command\n";
