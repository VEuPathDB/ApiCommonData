#!/usr/bin/perl

use strict;

my $db = shift;

foreach my $file (@ARGV){
  die "file $file does  not exist\n" unless (-e $file);
  print STDERR "\nProcessing $file\n\n";
  open(C,">loadCov.ctl") || die "Unable to open loadCov.ctl for writing\n";
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
coverage
)\n";
  close C;

  ##run sqlldr
  system("sqlldr apidb\@$db/po34weep control=loadCov.ctl");
}
