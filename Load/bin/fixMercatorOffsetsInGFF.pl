#!/usr/bin/perl


use strict;
use CBIL::Bio::SequenceUtils;
use Getopt::Long;

my($fastaFile,$gffFile);

&GetOptions("fastaFile|f=s" => \$fastaFile, 
            "gffFile|g=s"=> \$gffFile,
            );

die "provide fasta and gff files on command line\n" unless (-e "$fastaFile" && -e "$gffFile");

##parse fasta file ....
open(S,"$fastaFile");

my %seq; 
my $id = "";
while(<S>){
  if(/^\>(\S+)/){
    $id = $1;
  }else{
    chomp;
    $seq{$id} .= $_;
  }
}
close S;
print STDERR "Parsed ",scalar(keys%seq)," sequences\n";

##now the gff file
open(G,"$gffFile");
my %genes;
while(<G>){
  my @tmp = split("\t",$_);
  next unless $tmp[2] eq 'CDS';
  if($tmp[8] =~ /ID=(\S+?)\;/){
    push(@{$genes{$1}->{$tmp[2]}},\@tmp);
  }
}

print STDERR "Parsed ",scalar(keys%genes)," genes\n";

foreach my $id (keys%genes){
  my @exons;
  if($genes{$id}->{CDS}->[0]->[6] eq '+'){
    @exons = sort {$a->[3] <=> $b->[3]} @{$genes{$id}->{CDS}};
  }else{
    @exons = sort {$b->[3] <=> $a->[3]} @{$genes{$id}->{CDS}};
  }
  my $cds;
  foreach my $e (@exons){
    $cds .= &getSequence($e->[0],$e->[3],$e->[4],$e->[6]);
  }

  ##now translate and get offset ....
  my $offset = &getFirstOffset($id,$cds);
#  print "$id\t$offset\n";
  ##now finish the thing off and go ahead and compute offset and print out
  &printExons($id);
  my $first = shift(@exons);
  $first->[7] = $offset;
  print join("\t",@{$first});
  my @upstream;
  push(@upstream,$first);
  foreach my $ex (@exons){
    $ex->[7] = getOffset($offset,\@upstream);
    print join("\t",@{$ex});
    push(@upstream,$ex);

  }
}

sub getOffset {
  my($init,$ups) = @_;
  my $len = 0;
  foreach my $e (@{$ups}){
    $len += ($e->[4] - $e->[3]) + 1;
  }
  my $mod = ($len - $init) % 3;  ##adjust for that first exon problem
  return $mod == 0 ? 0 : 3 - $mod;
}

sub printExons {
  my($id) = @_;
  foreach my $e (@{$genes{$id}->{exon}}){
    print join("\t",$e);
  }
}

sub getSequence {
  my($id,$start,$end,$strand) = @_;
  $start--;  ##make into array context.  NOTE that now length is end - start;
  my $sequence = substr($seq{$id},$start,$end - $start);
  return $strand eq '+' ? $sequence : CBIL::Bio::SequenceUtils::reverseComplementSequence($sequence);
}

sub getFirstOffset {
  my($id,$seq) = @_;
  my %ret;
  my $first = CBIL::Bio::SequenceUtils::translateSequence($seq);
  chop $first;  ## remove final term if exists
  my $firstCt = ($first =~ tr/\*//);
  return 0 if $firstCt == 0;
  $ret{0} = $firstCt;
  $seq =~ s/^.//;
  my $second = CBIL::Bio::SequenceUtils::translateSequence($seq);
  chop $second;  ## remove final term if exists
  my $secondCt = ($second =~ tr/\*//);
  return 1 if $secondCt == 0;
  $ret{1} = $secondCt;
  $seq =~ s/^.//;
  my $third = CBIL::Bio::SequenceUtils::translateSequence($seq);
  chop $third;  ## remove final term if exists
  my $thirdCt = ($third =~ tr/\*//);
  return 2 if $thirdCt == 0;
  $ret{2} = $thirdCt;
  ##if here then need to print error msg and return the best one ...
  my @sort = sort{$ret{$a} <=> $ret{$b}}keys%ret;
  print STDERR "$id: All reading frames contain stop codons ($firstCt, $secondCt, $thirdCt) .. using $sort[0]\n";
  return $sort[0];
}
