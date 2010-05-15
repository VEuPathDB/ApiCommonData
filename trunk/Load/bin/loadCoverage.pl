#!/usr/bin/perl

use strict;
use File::Basename;

#my $db = shift;

foreach my $file (@ARGV){
  die "file $file does  not exist\n" unless (-e $file);
  my $directories = dirname($file);
  print STDERR "\nProcessing $file\n, output dir $directories\n";  
  open(C,">$directories/loadCov.ctl") || die "Unable to open loadCov.ctl for writing\n";
  print C "LOAD DATA
INFILE '$file'
APPEND
INTO TABLE apidb.nextgenseq_coverage
FIELDS TERMINATED BY '\\t'
TRAILING NULLCOLS
(external_database_release_id,
sample,
na_sequence_id,
location,
coverage,
multiple
)\n";
  close C;

  ##run sqlldr
  system("sqlLoader.pl --file $directories/loadCov.ctl");
}
