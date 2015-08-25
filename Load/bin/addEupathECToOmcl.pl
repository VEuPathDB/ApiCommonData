#!/usr/bin/perl

use strict;
use Getopt::Long;

my($orthoFile,$eupathFile,$orthoSeqWithEC);
my $eupathOnly = 0;
my $verbose = 0;

&GetOptions("orthoFile|o=s" => \$orthoFile, 
            "eupathFile|e=s" => \$eupathFile,
            "orthoSeqs|os=s" => \$orthoSeqWithEC,
            "EupathOnly!" => \$eupathOnly,  ## if true, replace orthoEC assignments with eupath ones
            "verbose|v!" => \$verbose,  ## if true then prints to stderr info ...
            );

##first open the orthoseqswithec file and get identifiers as don't want to add if this seq present
## [Accession]	[Source ID]	[EC Numbers]	[Group]	[Group Size]	
## aaeg|AAEL000109-PA	AAEL000109-PA	3.1.3.77	OG5_131070	47

my %haveEc;
if(-e "$orthoSeqWithEC"){
  open(F,"$orthoSeqWithEC") || die "Unable to open orthoSeqWithEC '$orthoSeqWithEC'\n";
  while(<F>){
    my @tmp = split("\t",$_);
    $haveEc{$tmp[1]} = $tmp[2];
  }
  print STDERR "Have ",scalar(keys%haveEc)," orthomcl sequences with EC assignments\n";
  close F;
}else{
  print STDERR "OrthoSeqsWithEC file '$orthoSeqWithEC' not found .. skipping\n";
}
##second open eupath file from STDIN .... geneid,EC numbers, oprtholog count, paralog count, ortholog group
## [Gene ID]	[EC Numbers]	[Ortholog count]	[Paralog count]	[Ortholog Group]	
## PBANKA_000010	null	207	43	OG5_127056

open(F,"$eupathFile") || die "Unable to open eupathdb $eupathFile\n";
my %eupEC;
while(<F>){
  chomp;
  my @tmp = split("\t",$_);
  next if $tmp[1] =~ /null/;
  next if $haveEc{$tmp[0]};
  foreach my $ec (split(/\; /,$tmp[1])){
    if($ec =~ /^(\d\S+)/){
      $eupEC{$tmp[4]}->{$1}++;
    }
  }
}
close F;

print STDERR "Have EC assignments for ",scalar(keys%eupEC)," groups\n";


##now the input ortho file
#groupid, #seqs, ave % conn, ave % id, EC numbers
## [Group]	[# Sequences]	[Average % Connectivity]	[Average % Identity]	[EC Numbers]	
## OG5_126536	3943	50	67.2	null
open(F,"$orthoFile") || die "Unable to open orthoFile $orthoFile\n";
my $new = 0;
my $added = 0;
while(<F>){
  chomp;
  my @tmp = split("\t",$_);
  if($eupEC{$tmp[0]}){  ##have an assignment for this one
    my $ec = $eupEC{$tmp[0]};
    my $eupEcString = &getEcString($ec);
    if($tmp[4] =~ /null/){  ##doesn't have an assignment
      print join("\t",@tmp[0..3]),"\t$eupEcString\n";
      $new++;
    }else{
      my $ecstring = &addEcString($tmp[4],$ec);
      if($eupathOnly){
        print join("\t",@tmp[0..3]),"\t$eupEcString\n";
      }else{
        print join("\t",@tmp[0..3]),"\t$ecstring\n";
      }
#      print STDERR "Adding EC: $tmp[4] + $eupEcString = $ecstring\n";
      $added++;
    }
    delete $eupEC{$tmp[0]};  ##want to know which ones I haven't used ....
  }else{
    if($eupathOnly){
        print join("\t",@tmp[0..3]),"\tnull\n";
    }else{
      print join("\t",@tmp),"\n";
    }
  } 
}
close F;

print STDERR "Added EC numbers to $new new OrthoMCL groups, $added existing groups and ",scalar(keys%eupEC)," assignments not added due to private orthomcl groups\n";
print STDERR "EuPathDB assignments that weren't added to orthomcl ...\n";
foreach my $k (keys%eupEC){
  my $ecString = &getEcString($eupEC{$k});
  print STDERR "  $k\t$ecString\n";
  print "$k\t50\t50\t50\t$ecString\n";
}

sub getEcString {
  my ($ec) = @_;  ##take in hash reference ....
  my @ret;
  foreach my $k (keys%{$ec}){
    push(@ret,"$k ($ec->{$k})");
  }
  my $ret = join(", ",@ret);
  print STDERR "getEcString(",join(", ",keys%{$ec}),"): $ret\n" if $ret eq "";
  return $ret;
}

sub addEcString {
  my($ortho,$eupath) = @_;
  my @ret;
  foreach my $e (split(", ",$ortho)){  # split on comma
    my($ec,$ct) = split(" ",$e);
    $ct =~ s/\((\d+)\)/$1/;
    if($eupath->{$ec}){  #have this one from eupathdb as well
      $ct += $eupath->{$ec};
      delete $eupath->{$ec};
    }
    push(@ret,"$ec ($ct)");
  }
  foreach my $k (keys%{$eupath}){
    push(@ret,"$k ($eupath->{$k})");
  }
  return join(", ",@ret);
}

