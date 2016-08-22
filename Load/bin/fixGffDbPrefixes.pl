#!/usr/bin/perl
#vvvvvvvvvvvvvvvvvvvvvvvvv GUS4_STATUS vvvvvvvvvvvvvvvvvvvvvvvvv
  # GUS4_STATUS | SRes.OntologyTerm              | auto   | absent
  # GUS4_STATUS | SRes.SequenceOntology          | auto   | absent
  # GUS4_STATUS | Study.OntologyEntry            | auto   | absent
  # GUS4_STATUS | SRes.GOTerm                    | auto   | absent
  # GUS4_STATUS | Dots.RNAFeatureExon            | auto   | absent
  # GUS4_STATUS | RAD.SageTag                    | auto   | absent
  # GUS4_STATUS | RAD.Analysis                   | auto   | absent
  # GUS4_STATUS | ApiDB.Profile                  | auto   | absent
  # GUS4_STATUS | Study.Study                    | auto   | absent
  # GUS4_STATUS | Dots.Isolate                   | auto   | absent
  # GUS4_STATUS | DeprecatedTables               | auto   | absent
  # GUS4_STATUS | Pathway                        | auto   | absent
  # GUS4_STATUS | DoTS.SequenceVariation         | auto   | absent
  # GUS4_STATUS | RNASeq Junctions               | auto   | absent
  # GUS4_STATUS | Simple Rename                  | auto   | absent
  # GUS4_STATUS | ApiDB Tuning Gene              | auto   | absent
  # GUS4_STATUS | Rethink                        | auto   | absent
  # GUS4_STATUS | dots.gene                      | manual | unreviewed
die 'This file has broken or unreviewed GUS4_STATUS rules.  Please remove this line when all are fixed or absent';
#^^^^^^^^^^^^^^^^^^^^^^^^^ End GUS4_STATUS ^^^^^^^^^^^^^^^^^^^^

# use in download directory for setting the GFF identifer prefixes = fasta prefixes
# takes in organism directories on commandline ... will decend into each and fix the gff files
# creates a .bak file of the original gff file

use strict;
use Getopt::Long;

my $nb;

&GetOptions("noBackup|n!" => \$nb
            );


foreach my $dir (@ARGV){
  die "you must enter a directory (or list of directories) that contain fasta and gff subdirs\n" if scalar(@ARGV) == 0;
  my $findCmd = "find $dir/fasta -name '*.fasta' -print";
  print STDERR "Processing $dir\n";
  my @fasta = `$findCmd`;
  my %sub;
  foreach my $fasta (@fasta){
    chomp $fasta;
    next unless $fasta =~ /(Annotated|Genomic)/;
    open(F,"$fasta");
    while(<F>){
      if(/^\>(\w+\|)(\S+)/){
        $sub{$2} = $1;
      }
    }
    close F;
  }
  print STDERR "  found prefixes for ".scalar(keys%sub)." identifiers\n";
  ##now open the gff file ....
  my $gffFind = "find $dir/gff -name '*.gff' -print";
#  print STDERR "gffFindCmd: '$gffFind'\n";
  my @gffFiles = `$gffFind`;
  foreach my $gff (@gffFiles){
    chomp $gff;
    print STDERR "  Making substitutions in $gff\n";
    my $mvCmd = "mv $gff $gff.bak";
#    print STDERR "Move Cmd: '$mvCmd'\n";
    system($mvCmd) unless -e "$gff.bak";  ##don't move if already there
    open(F,"$gff.bak");
    open(O,">$gff");
    while(<F>){
      while($_ =~ m/apidb\|(.*?)(\;|\s)/g){
        my $id = $1;
        $_ =~ s/apidb\|$id/$sub{$id}$id/; ##note that this will strip the prefix if this is not an id in a fasta file.
      }
      $_ =~ s/ApiDB/EuPathDB/g;  ##get rid of old ApiDB references.
      print O $_;
    }
    close F;
    close O;
    unlink("$gff.bak") if $nb;
  }
}
      
