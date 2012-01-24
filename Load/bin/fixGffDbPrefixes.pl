#!/usr/bin/perl

# use in download directory for setting the GFF identifer prefixes = fasta prefixes
# takes in directories on commandline ... will decend into each and fix the gff files

use strict;


foreach my $dir (@ARGV){
  my $findCmd = "find $dir/fasta -name '*Genomic_*' -print | grep -v ^\.";
  print STDERR "Processing $dir: $findCmd\n";
  my @fasta = `$findCmd`;
  my %sub;
  foreach my $fasta (@fasta){
    chomp $fasta;
    open(F,"$fasta");
    while(<F>){
      if(/^\>(\w+)\|(\S+)/){
        $sub{$2} = $1;
      }
    }
    close F;
  }
  ##now open the gff file ....
  my $gffFind = "find $dir/gff -name '*.gff' -print | grep -v ^\.";
  my @gffFiles = `$gffFind`;
  foreach my $gff (@gffFiles){
    system("mv $gff $gff.bak") unless -e "$gff.bak";  ##don't move if already there
    open(F,"$gff.bak");
    open(O,">$gff");
    while(<F>){
      my @line = split("\t",$_);
      if($line[0] =~ /apidb\|(\S+)/){
        my $id = $1;
        if($sub{$id}){
          $line[0] =~ s/apidb\|$id/$sub{$id}\|$id/g;
        }else{
          print STDERR "ERROR: unable to match id for $line[0]\n";
      }
      $line[1] =~ s/ApiDB/EuPathDB/;
      $line[8] =~ s/apidb//g;
      print O join("\t",@line);
    }
    close F;
    close O;
  }
}
      
