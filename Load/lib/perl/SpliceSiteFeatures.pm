package ApiCommonData::Load::SpliceSiteFeatures;
use base qw(CBIL::TranscriptExpression::DataMunger::Loadable);

use strict;

use Data::Dumper;

sub getSampleName {$_[0]->{sampleName}}

sub getInputs {$_[0]->{inputs}}
sub getSuffix {$_[0]->{suffix}}
sub getSpliceSiteType {$_[0]->{spliceSiteType}}

sub new {
  my ($class, $args) = @_;

  my $requiredParams = [
                          'sampleName',
                          'inputs',
                          'suffix',
                         'spliceSiteType'
                         ];
  my $self = $class->SUPER::new($args, $requiredParams);

  my $cleanSampleName = $self->getSampleName();
  $cleanSampleName =~ s/\s/_/g; 
  $cleanSampleName=~ s/[\(\)]//g;

  my $outputFile = $cleanSampleName . $self->getSuffix();
  $self->setOutputFile($outputFile);

  $self->setProtocolName("Splice Site Features");
  $self->setDisplaySuffix(" [feature_loc]");

  $self->setSourceIdType('segment');

  my $sampleName = $self->getSampleName();
  my $inputs = $self->getInputs();

  $self->setNames([$sampleName]);
  $self->setFileNames([$outputFile]);

  $self->setInputProtocolAppNodesHash({$sampleName => $inputs});


  return $self;
}


sub munge {
  my ($self) = @_;

  # most of this is coming direclty from the plugin called ApiCommonData::Load::Plugin::InsertSpliceSiteFeatures.pm
  $self->{alignCount}={};
  $self->{mismatches} ={};

  my $input = $self->getInputs()->[0];

  my $mainDirectory = $self->getMainDirectory();

  my $file = $mainDirectory . "/" .$input . ".bt";

  my $all_uniq_counts = 0; # to keep count of ALL unique alignments; needed for normalizing counts later

  my $key;

  open(FILE, $file) or die "Cannot open file $file for reading: $!";


  while (<FILE>){
    chomp;

    # -----------------------------------------------------------------------------------------------------------------------
    # BOWTIE OUTPUT:
    # 0          1       2               3                            4           5              6              7
    # Query_ID   Strand  Target_ID       Target_start(0_offset)  QuerySeq         Qualities	   -M_ceiling	  mismatches
    # 1272       -       Tb927_11_01_v4  2099739                 TCAGGTTGCCC..    IIIIIII...     0              71:T>G,72:C>G
    #
    # -----------------------------------------------------------------------------------------------------------------------

    my @temp = split("\t", $_);
    my $naSeqId = $temp[2];

    my $location = $temp[3];
    my $seqLen = length($temp[4]);

    # bowtie results have zero-based offset
    $location = $location + 1;
    # for reverse strand, location = location in bowtie result + length of match - 1
    $location = $location + $seqLen - 1 if ($temp[1] eq "-");

    my $isUniq = 0;
    $isUniq = 1 if ($temp[6] == 0);
    $all_uniq_counts++ if ($isUniq);

    # set hash key as the unique combination of seq_id, location, strand and isUniq
    $key = "$naSeqId\t$location\t$temp[1]\t$isUniq";

    $self->{alignCount}->{$key}++;  # increment alignment count for each occurrence of a particular hash key

    if ($temp[7]){
      my @misCount = split("\,",$temp[7]); # last field of bowtie output gives comma-separated mis-matches
      $self->{mismatches}->{$key} += $#misCount + 1;  # increment number of total mis-matches for the same alignment
    }

  }
  close (FILE);

  $self->writeSpliceSiteFeatures($all_uniq_counts);

  $self->createConfigFile();

}


sub writeSpliceSiteFeatures {
  my ($self, $all_uniq_counts) = @_;

  my $outputFile = $self->getOutputFile();
  open(OUT, ">$outputFile") or die "Cannot open output file $outputFile for writing:$!";



  my %alignments = %{$self->{alignCount}};
  my @matches = sort (keys(%alignments));

  my @header = ("SequenceId", "segment_start", "segment_end", "type", "strand", "count", "is_unique", "avg_mismatches", "count_per_million");
  print OUT join("\t", @header) . "\n";

  foreach my $hit (@matches) {

    # NOTE format for $hit IS: "$naSeqId\t$location\t$strand\t$isUniq"
    my @m = split("\t",$hit);
    my $alignCount = $self->{alignCount}->{$hit};

    my $mismatch = $self->{mismatches}->{$hit} || 0;
    my $avg_mismatch = sprintf "%.2f", ($mismatch / $alignCount);

    my $countPerMill = sprintf "%.2f", ($alignCount * 1000000) / ($all_uniq_counts);

## output
    my @line = ($m[0], $m[1], $m[1], $self->getSpliceSiteType(), $m[2], $alignCount, $m[3], $avg_mismatch, $countPerMill);

    print OUT join("\t", @line) . "\n";
  }
}

1;
