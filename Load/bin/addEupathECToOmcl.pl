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
## Accession   Source ID   Number of Core Proteins   Number of Peripheral Proteins   Group ID   EC Numbers
## aacu|ASPACDRAFT_109660   ASPACDRAFT_109660   84   171   OG6_103198   4.1.1.48, 4.1.3.27, 5.3.1.24

my %haveEc;
if(-e "$orthoSeqWithEC"){
  open(F,"$orthoSeqWithEC") || die "Unable to open orthoSeqWithEC '$orthoSeqWithEC'\n";
  while(<F>){
      chomp;
      my @tmp = split("\t",$_);
      my ($accession,$sourceId,$numCore,$numPeripheral,$group,$ecs) = @tmp;
      my $total = $numCore + $numPeripheral;
      next unless ($total > 1);
      next unless ($ecs && $group);
      $haveEc{$sourceId} = $ecs;
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
  my ($geneId,$ecs,$numOrthologs,$numParalogs,$group) = @tmp;
  next if $ecs =~ /null/;
  next if $haveEc{$geneId};
  foreach my $ec (split(/\; /,$ecs)){
    if($ec =~ /^(\d\S+)/){
      $eupEC{$group}->{$1}++;
    }
  }
}
close F;

print STDERR "Have EC assignments for ",scalar(keys%eupEC)," groups\n";


##now the input ortho file
#Ortholog Group  Total Number Proteins  EC Numbers  % Homology  Average % Identity
#OG6_100000  12129  2.7.7.49 (116), 2.3.2.27 (8), 3.6.4.12 (3), 2.7.7.7 (2), 3.1.26.4 (2), 3.4.23.- (2), 5.6.2.1 (2), 2.3.2.31 (1), 3.1.26.13 (1
#), 3.1.4.11 (1), 3.4.11.18 (1), 3.6.1.15 (1), 3.6.1.7 (1), 4.1.1.15 (1), 6.1.1.18 (1), 6.1.1.7 (1)  11.3  41
#OG6_100001  7068  N/A  23.7  83

open(F,"$orthoFile") || die "Unable to open orthoFile $orthoFile\n";
my $new = 0;
my $added = 0;
while(<F>){
  chomp;
  my @tmp = split("\t",$_);
  my ($group,$num,$ecs,$homology,$identity) = @tmp;
  $ecs = "null" if ($ecs =~ /N\/A/);
  if($eupEC{$group}){  ##have an assignment for this one
    my $ec = $eupEC{$group};
    my $eupEcString = &getEcString($ec);
    if($ecs eq "null"){  ##doesn't have an assignment
      print "$group\t$num\t$homology\t$identity\t$eupEcString\n";
      $new++;
    }else{
      my $ecString = &addEcString($ecs,$ec);
      if($eupathOnly){
        print "$group\t$num\t$homology\t$identity\t$eupEcString\n";
      }else{
        print "$group\t$num\t$homology\t$identity\t$ecString\n";
      }
#      print STDERR "Adding EC: $ecs + $eupEcString = $ecString\n";
      $added++;
    }
    delete $eupEC{$group};  ##want to know which ones I haven't used ....
  }else{
    if($eupathOnly){
        print "$group\t$num\t$homology\t$identity\tnull\n";
    }else{
      print "$group\t$num\t$homology\t$identity\t$ecs\n";
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

