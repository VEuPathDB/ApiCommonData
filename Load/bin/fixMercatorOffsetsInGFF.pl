#!/usr/bin/perl


use strict;
use CBIL::Bio::SequenceUtils;
use Getopt::Long;

my($fastaFile,$gffFile,$outFile,$gffRegex,$fastaRegex);

&GetOptions("fastaFile|f=s" => \$fastaFile, 
            "gffFile|g=s"=> \$gffFile,
            "outFile|o=s"=> \$outFile,
            "gffRegex|gr=s"=> \$gffRegex,
            "fastaRegex|fr=s"=> \$fastaRegex,
            );

die "provide fasta, gff and output files on command line\nfixMercatorOffsetsInGFF.pl --f <fastaFile> --g <gffFile> --o <outFile> --fr <fastaRegex ['^\>(\S+)']> --gr <gffRegex for sequence id ['(\S+)']>\n" unless (-e "$fastaFile" && -e "$gffFile" && $outFile);

$fastaRegex = '^\>(\S+)' unless $fastaRegex;
$gffRegex = '(\S+)' unless $gffRegex;

##parse fasta file ....
open(S,"$fastaFile");

my %seq; 
my $id = "";
while(<S>){
#  if(/^\>(\S+)/){
  if(/$fastaRegex/){
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
my @lines;
while(<G>){
  my @tmp = split("\t",$_);
  push(@lines,\@tmp);
  next unless $tmp[2] eq 'CDS';
  if($tmp[8] =~ /ID=(\S+?)\;/){
    push(@{$genes{$1}->{$tmp[2]}},\@tmp);
  }
}
close G;
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
    my ($sid) = ($e->[0] =~ /$gffRegex/);
    $cds .= &getSequence($sid,$e->[3],$e->[4],$e->[6]);
  }

  ##now translate and get offset ....
  my $offset = &getFirstOffset($id,$cds);
#  print "$id\t$offset\n";
  ##now finish the thing off and go ahead and compute offset and print out
  my $first = shift(@exons);
  $first->[7] = $offset; ##sets offset of the first exon
  my @upstream;
  push(@upstream,$first);
  foreach my $ex (@exons){
    $ex->[7] = getOffset($offset,\@upstream);
    push(@upstream,$ex);
  }
}

##now print the whole thing out
open(F,">$outFile");
foreach my $l (@lines){
  print F join("\t",@{$l});
}
close F;

sub getOffset {
  my($init,$ups) = @_;
  my $len = 0;
  foreach my $e (@{$ups}){
    $len += ($e->[4] - $e->[3]) + 1;
  }
  my $mod = ($len - $init) % 3;  ##adjust for that first exon problem
  return $mod == 0 ? 0 : 3 - $mod;
}

sub getSequence {
  my($id,$start,$end,$strand) = @_;
  print STDERR "Unable to find '$id' in sequence file $fastaFile\n" unless $seq{$id};
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
  my $return = $ret{$sort[0]} <= 2 ? $sort[0] : 0;
  print STDERR "$id: All reading frames contain stop codons ($firstCt, $secondCt, $thirdCt) .. using $return\n";
  return $return;
}
