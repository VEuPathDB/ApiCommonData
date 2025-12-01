#!/usr/bin/perl

### usage: perl makeManDelDirAtVersion.pl version subdirectory
### eg.    perl makeManDelDirAtVersion.pl 2011-12-01 GeneDB_GFF

use strict;


my ($version, $dir) = @ARGV;

my ($cmd1, $cmd2, $cmd3);

if ($dir) {
	$cmd1 = "mkdir -p $dir/$version/final";
	$cmd2 = "mkdir $dir/$version/workSpace";
	$cmd3 = "mkdir $dir/$version/fromProvider";
} else {
	$cmd1 = "mkdir -p $version/final";
	$cmd2 = "mkdir $version/workSpace";
	$cmd3 = "mkdir $version/fromProvider";
}

`$cmd1`;
`$cmd2`;
`$cmd3`;

