#!/usr/bin/perl

use strict;
use Getopt::Long;

my($orthoFile,$eupathFile);
my $minOrthologCt = 0;
my $maxOrthologCt = 10000;
my $verbose = 0;
my $printDiff = 0;
my $loadFormat = 0;

&GetOptions("orthoFile|o=s" => \$orthoFile, 
            "eupathFile|e=s" => \$eupathFile,
            "minOrthoCt|min=i" => \$minOrthologCt,
            "maxOrthoCt|max=i" => \$maxOrthologCt,
            "verbose|v!" => \$verbose,  ## if true then prints to stderr info ...
            "printDiff|pd!" => \$printDiff,  ## if true then prints to stderr differences ...
            "loadFormat|lf!" => \$loadFormat,  ## if true then prints just two columns for loading with EC number plugin
            );
my $gid;
my $conn;
my $ident;
my $ecstring;
my $numSeqs;
my %consGrps;
my %ortho;

open(F,"$orthoFile") || die "unable to open ortholog file '$orthoFile'\n";
while(<F>){
  chomp;
  my @tmp = split("\t",$_);
  next if($tmp[4] =~ /null/);  ##doesn't have an assignment
  next if $tmp[0] =~ /Group/;
  my($ec,$ct) = &procEC($tmp[4]);
  $ortho{$tmp[0]} = join("\t",@tmp);
  if ($ct / $tmp[1] > 0){
    #        print "$gid\t$numSeqs\t$conn\t$ident\t",($ec ? "$ec\t$ct" : "inconsistent"),"\n";
    $consGrps{$tmp[0]} = [$ec,$ct,$tmp[1],$tmp[2],$tmp[3]];
  }
}
close F;

my $ctOutsideGroupSize = 0;
my $ctTot = 0;
my $ctNew = 0;
my $ctSame = 0;
my $ctDiff = 0;
my $ctLessDef = 0;
my $ctMoreDef = 0;
my $ctMissed = 0;
my $ctMissedWithGrp = 0;
my %missed;
my %matchLevel;

open(F,"$eupathFile") || die "unable to open eupathdb file '$eupathFile'\n";
while(<F>){
  chomp;
  if(/Gene\sID/){
    if($loadFormat){
      print "Source_id\tEC_number\n";
    }else{
      print "$_\tOrtho EC\tWithEC_ct\tGroup Ct\tconnectivity\tidentity\n";
    }
  }else{
    my @tmp = split("\t",$_);
    if ($tmp[2] > $maxOrthologCt || $tmp[2] < $minOrthologCt){ #number orthogs
      $ctOutsideGroupSize++;
      next;
    }
    if($consGrps{$tmp[4]}){
      $ctTot++;
      if($loadFormat){
        print "$tmp[0]\t$consGrps{$tmp[4]}->[0]\n";
      }else{
        print "$_\t",join("\t",@{$consGrps{$tmp[4]}}),"\n";
      }
      if(length($tmp[1]) > 5){
        &checkIfMatches($consGrps{$tmp[4]}->[0],$tmp[1],$tmp[4]);
      }else{
        $ctNew++;
      }
    }elsif(length($tmp[1]) > 5){
      $ctMissed++;
      $ctMissedWithGrp++ if $ortho{$tmp[4]};
      $missed{substr($tmp[0],0,4)}++;
      print STDERR "Missed: $_\n  Ortho: $ortho{$tmp[4]}\n" if $verbose;
    }
  }
}
close F;
print STDERR "Assigned ECs to $ctTot total genes, $ctNew new , $ctSame same, $ctLessDef less defined, $ctMoreDef more defined, $ctDiff different ... matchLevels=(",&getMatchLevels(),"), $ctMissed missed and $ctOutsideGroupSize outside group size, \n";
if($verbose){
  if(scalar(keys%missed) < 20){
    print STDERR "Missed these\n";
    foreach my $id (sort{$missed{$b} <=> $missed{$a}}keys%missed){
      print STDERR "  $id: $missed{$id}\n";
    }
  }
}

sub getMatchLevels {
  my @ret;
  for(my $a=0;$a<4;$a++){
    push(@ret,"$a=$matchLevel{$a}");
  }
  return join(", ",@ret);
}

sub checkIfMatches {
  my($newEc,$ecstring,$ortho) = @_;
  my @ecs = split(/\; /,$ecstring);
  my @oldEcs;
  foreach my $e (@ecs){
    if($e =~ /^(\S+)/){
      my $tmp = $1;
      push(@oldEcs,$tmp) if $tmp =~ /^\d+\.\d+/;
    }
  }
  #now first check to see if any match exactly
  foreach my $oldEc (@oldEcs){
    if($oldEc eq $newEc){
      $ctSame++;
      return;
    }
  }
  #next check to see if any less defined ....
  my $intactNewEc = $newEc;
  if($newEc =~ /-$/){
    $newEc =~ s/-//g;
    $newEc =~ s/^(.*\d)\./$1/;
    foreach my $oldEc (@oldEcs){
      if($oldEc =~ /^$newEc/){
        $ctLessDef++;
        return;
      }
    }
  }
  ##or it could be more defined ..
  foreach my $oEc (@oldEcs){
    if($oEc =~ /-$/){
      $oEc =~ s/-//g;
      $oEc =~ s/^(.*\d)\./$1/;
      if($intactNewEc =~ /^$oEc/){
        $ctMoreDef++;
        return;
      }
    }
  }
  ##now check to see the highest level that it matches
  my @num = split(/\./,$intactNewEc);
  my @level = ("$num[0]","$num[0].$num[1]","$num[0].$num[1].$num[2]");
  my $lev = 0;
  for(my $a = 0;$a<3;$a++){
    foreach my $oldEc (@oldEcs){
      if($oldEc =~ /^$level[$a]\./){
        $lev = $a + 1;
      }
    }
  }
  $matchLevel{$lev}++;

  print STDERR "Old: (",join(", ",@oldEcs),") -> NewEC: '$intactNewEc'\n  OrthoMCL: $ortho{$ortho}\n" if $verbose || $printDiff;
  $ctDiff++;
}

##what to do here ... want to know the structure in some sense .. ie, how many positions match.
##ignore if two -
##if none fully qualified then return with one - if exists
##only return if all match at first three characters ... otherwise count as inconsistent.
##return highest match level, EC number with highest count, count.  Only return if consistent
##to third level at some percentage.  If multiple 4th levels, return with - at 4th or if large bias toward one then that one
sub procEC {
  my($ecnums) = @_;
  ##print STDERR "procEC: $ecnums\n";
  chomp $ecnums;
  my %ec;
  foreach my $a (split(", ",$ecnums)){
    my($ec,$ct) = split(" ",$a);
    $ct =~ s/[\(\)]//g;
    $ec{$ec} = $ct;
#    print "procEC->ecs: $ec\t$ct\n";
  }
  my($freqec,$freqct) = &returnMostFrequent(\%ec);
  return  ($freqec,$freqct) if $freqct >= 1;
}

##what todo here ...
sub getBestEc {
  my($data) = @_;
  my $count = { '1' => scalar(keys%{$data->{'1'}}),
                '2' => scalar(keys%{$data->{'2'}}),
                '3' => scalar(keys%{$data->{'3'}}),
                '4' => scalar(keys%{$data->{'4'}}) };
  if($count->{3} == 1){  ##consistent out through 3rd position ...
    my($ct,$ec,$perc) = &getEcValues($data->{3});
  }
}

##intent here is to take in a hash and return based on the number of
##keys and if more than one, to return the number and also the best
##one with % that one encompasses return array of values, the count of ecs, the ec number, the percent of total for this ec

sub getEcValues {
  my($hash) = @_;
  my $ct = scalar(keys%{$hash});
  

}

##return the level to which an EC is specified ... 1-4
sub getSpecifiedLevel {
  my($ec) = @_;
  my @num = split(/\./,$ec);
  for(my $a = 0;$a<scalar(@num);$a++){
    return $a if $num[$a] eq '-';  ##note that returning highest level
                                   ##specified so if - then one above.
  } 
  return scalar(@num);
}

sub isFullySpecified {
  my($ec) = @_;
  my @num = split(/\./,$ec);
  for(my $a = 0;$a<scalar(@num);$a++){
    return 0  
  } 
  return 1;
}

sub getCons {
  my($pos) = @_;
  return 0 if scalar(keys%{$pos}) > 1;
  foreach my $a (keys%{$pos}){
    return 0 if scalar(keys%{$pos->{$a}}) > 1;
    foreach my $b (keys%{$pos->{$a}}){
      my %last; my $tot;
      foreach my $c (keys%{$pos->{$a}->{$b}}){
        foreach my $d (keys%{$pos->{$a}->{$b}->{$c}}){
          if($d eq "-"){
            #            print "not specific: $a.$b.$c.$d\t$pos->{$a}->{$b}->{$c}->{$d}\n";
          }else{
            $last{$d} = $pos->{$a}->{$b}->{$c}->{$d}; 
          }
          $tot += $pos->{$a}->{$b}->{$c}->{$d};
        }
        if(scalar(keys%{$pos->{$a}->{$b}}) == 1){
          my @tmp = keys(%last);
          return ("$a.$b.$c.".(scalar(@tmp) == 1 ? "$tmp[0]" : "-"),$tot);
        }
      } 
      return ("$a.$b.-.-",$tot);
    } 
  }
}

sub returnMostFrequent {
  my($ecnums) = @_;
  my @sorted = sort{$ecnums->{$b} <=> $ecnums->{$a}}keys%{$ecnums};
  my @same;
  for(my $a=0;$a<scalar(@sorted);$a++){
    last if ($a > 0 && $ecnums->{$sorted[$a-1]} > $ecnums->{$sorted[$a]});
    push(@same,$sorted[$a]);
  }
  my $best = shift(@sorted);
  my $tot = 0;
  return ($best,$ecnums->{$best}) if scalar(@same) == 1; ####only one so return
  my ($ec) = &getMostConsistent(\@same);
  print STDERR "NO BEST: ",join(", ",@same)," -> $ec\n" if $verbose;
  return ($ec,$ecnums->{$best}) if $ec;
 
}

sub getMostConsistent {
  my($ecs) = @_;
  my %data;my %pos;
  my @fullySpec;
  foreach my $ec (@{$ecs}){
    my @num = split(/\./,$ec);
    push(@fullySpec,$ec) unless $num[3] eq '-';
    $data{1}->{"$num[0]"}++;
    $data{2}->{"$num[0].$num[1]"}++;
    $data{3}->{"$num[0].$num[1].$num[2]"}++;
    $data{4}->{"$num[0].$num[1].$num[2].$num[3]"}++;
    $pos{$num[0]}->{$num[1]}->{$num[2]}->{$num[3]}++;
  }
  return $fullySpec[0] if scalar(@fullySpec) == 1;
  my($consec,$consct) = &getCons(\%pos);
  return $consec if $consct;
  return 0;
}
