package ApiCommonData::Load::SpliceSiteFeatures;
use base qw(CBIL::StudyAssayResults::DataMunger::Loadable);

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


#SRR038729.15770	0	Tb927_11_v5.1	2698338	42	43M	*	0	0	GAAGGTTATTTGATACTCGAACATGGCGAAGTCGAAGAACCAC	IIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIII	AS:i:0	XN:i:0	XM:i:0	XO:i:0	XG:i:0	NM:i:0	MD:Z:43	YT:Z:UU


    my ($query, $bitwise, $naSeqId, $location, $mapQ, $cigar, $mateRef, $mateLoc, $fragmentLength, $seq, $qualities, @tags) = split("\t", $_);

    next if($query =~ /^\@/);
    next if($naSeqId eq '*');


    my $seqLen = length($seq);

    # bowtie2 results have 1-based offset
    $location = $location;

    # deal w/ the bitwise opertor
    my $strand = $bitwise & 16 ? '-' : '+';

    # for reverse strand, location = location in bowtie result + length of match - 1
    $location = $location + $seqLen - 1 if ($strand eq "-");

    my $isUniq = 1;
    my $numberOfMismatches = 0;
    foreach(@tags) {
      $isUniq = 0 if /XS:i/;

      if(/XM:i:(\d+)/) {
        $numberOfMismatches = $1;
      }
    }

    $all_uniq_counts++ if ($isUniq);

    # set hash key as the unique combination of seq_id, location, strand and isUniq
    $key = "$naSeqId\t$location\t$strand\t$isUniq";

    $self->{alignCount}->{$key}++;  # increment alignment count for each occurrence of a particular hash key

    if ($numberOfMismatches){
      $self->{mismatches}->{$key} += $numberOfMismatches;
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
