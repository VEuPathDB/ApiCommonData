#!/usr/bin/perl -w

# Removes duplicate lines from a file
# Original file is overwritten, but the content order is preserved
# Usage: script filename.gff [file2.gff] [file3.gff] ...

use strict;
my (@data, %hash, $file) = ((), (), "");

if (not defined $ARGV[0]) {
	print "Usage: script filename.gff [file2.gff] [file3.gff] ...\n";
	exit -1;
}
foreach $file (@ARGV) {
	if (!open FILE, "+<$file") {
		print "Unable to open input csv file for read-write, '$file' $!\n";
		next;
	}
	while (<FILE>) {
		if (not exists $hash{$_}) {
			push @data, $_;
			$hash{$_} = 1;
		}
	}
	truncate FILE, 0;
	seek FILE, 0, 0;
	print FILE @data;
	close FILE;
	%hash = @data = ();
}
