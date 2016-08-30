package ApiCommonData::Load::OTUAnalysis;
use base qw(CBIL::TranscriptExpression::DataMunger::Loadable);

use strict;

use CBIL::TranscriptExpression::Error;
use CBIL::TranscriptExpression::Utils;

use ApiCommonData::Load::AlphaDiversityStats;

use Data::Dumper;

use File::Basename;
use File::Temp qw/ tempfile /;

my $DEFAULT_MAPPING_FILE = "taxa_map.txt";

#-------------------------------------------------------------------------------

 sub getProfileSetName          { $_[0]->{profileSetName} }

#-------------------------------------------------------------------------------
sub new {
  my ($class, $args) = @_;
    my $requiredParams = [
                                            'inputFile',
                                            'outputFile',
                                            'profileSetName',
                         ];

  my $self = $class->SUPER::new($args, $requiredParams);
  return $self;
}

sub munge {
  my ($self) = @_;

  my $inputFile = $self->getInputFile();
  my $dataFile = $inputFile;

  my $mainDir = $self->getMainDirectory();
  my $mappingFile = defined $self->getMappingFile() ? $self->getMappingFile() : $mainDir."/".$DEFAULT_MAPPING_FILE;

  my $outputFile = $self->getOutputFile();
  my $output_dir = $self->getMainDirectory()."/.".$outputFile."/";

  mkdir($output_dir) unless -d $output_dir;

  if ($inputFile =~/.biom$/) {
    $dataFile=$inputFile;
    $dataFile=~s/.biom$/.tab/;
    my $rFile = $self->parseBiomFile($inputFile, $dataFile);
    $self->runR($rFile);
  }

  $self->setProtocolName('taxonomic_diversity_assessment_by_targeted_gene_survey');

  my ($samples, $fileNames, $dataHash,  $totalCounts) = $self->parseOtuFile($dataFile, $output_dir);

  $self->setNames($samples);
  $self->setFileNames($fileNames);

  $self->setTechnologyType('OTU');
  my $emptyArrayRef = [];
  my %samplesHash =  map { $_ => $emptyArrayRef } @$samples;
  # my $samplesHash = $self->groupListHashRef($samples);
  foreach my $sampleName (keys %samplesHash) {

    my $alphaDiversityStats = ApiCommonData::Load::AlphaDiversityStats->new({sampleName => $sampleName,
                                                                             inputs => [$sampleName],
                                                                             dataHash => $dataHash->{$sampleName},
                                                                             rawCount => $totalCounts->{$sampleName},
                                                                             mainDirectory => $self->getMainDirectory,
                                                                             profileSetName => $self->getProfileSetName(),
                                                                             samplesHash => \%samplesHash,
                                                                             suffix => '_alpha_diversity.tab'});
    $alphaDiversityStats->setProtocolName("alpha_diversity");
    $alphaDiversityStats->setDisplaySuffix(" [alpha_diversity]");
    $alphaDiversityStats->setTechnologyType($self->getTechnologyType());
	
    $alphaDiversityStats->munge();
  }
  $self->setInputProtocolAppNodesHash(\%samplesHash);

  $self->createConfigFile(); 
}


sub parseBiomFile {
  my ($self,$biomFile,$dataFile) =@_;

  my $mainDir = $self->getMainDirectory();
  my $inputFile = $self->getInputFile;
  my $outputFile = $mainDir."/".$self->getOutputFile;
 $outputFile =~s/\/\//\//;

  my ($fh, $rFile) = tempfile(DIR => "/tmp/", suffix=>".R");
 

  open(RCODE, "> $rFile") or die "Cannot open $rFile for writing:$!";

  my $rString = <<RString;

file_input = "$inputFile";
file_output = "$dataFile";
source("$ENV{GUS_HOME}/lib/R/TranscriptExpression/parse_biom.R");

biom.obj = read_hdf5_biom(file_input);

otu=data.frame(biom.obj\$data);
otu=t(otu);
ID <- unlist(lapply(biom.obj\$rows, "[[", "id"));
otu = cbind(ID,otu)
write.table(otu, file=file_output, quote = FALSE, sep ="\t", row.names=FALSE);



RString
  print RCODE $rString;

  close RCODE;

  return $rFile;


}

sub parseOtuFile {
  my ($self, $dataFile, $output_dir) = @_;
  
  open (OTU, "<$dataFile");
  
  my $header = <OTU>;
  $header=~s/\n|\r//g;
  my @sample_ids = split("\t",$header);
  shift @sample_ids;

#  @sample_ids = map{ $_ . " (OTU)" }@samples;

  my $data_hash = {};
  my $total_counts = {};
  my $otu_id = [];
  while  (my $line = <OTU>) {
    my @values = split ("\t",$line);
    my $otu_id = shift @values;
    my $i = 0;
    while ($i < (scalar (@values))) {
      unless ($values[$i] =~/NA/i || !defined $values[$i] || $values[$i] ==0) {
        $data_hash->{$sample_ids[$i]}->{$otu_id} = $values[$i];
        $total_counts->{$sample_ids[$i]} = defined $total_counts->{$sample_ids[$i]} ? $total_counts->{$sample_ids[$i]} + $values[$i] : $values[$i];
      }
      $i++;
    }
  }
  my $ordered_samples = [];
  my $ordered_file_names = [];
  while (my ($sample_id, $abundanceHash) = each %$data_hash) {
    my $outputFileLocation = $output_dir.$sample_id;
    $outputFileLocation =~ s/\s/_/;
    $outputFileLocation =~ s/[\(\)]//g;
    $outputFileLocation =~ s/\/\//\//g;
    push (@$ordered_samples, $sample_id);
    my $outputFile = $self->getOutputFile();
    push (@$ordered_file_names, ".".$outputFile."/".$sample_id);
    open (OUT, ">$outputFileLocation") or die "unable to open file $outputFileLocation: $!";
    print OUT "ID\traw_count\trelative_abundance\n";
    while (my ($otu_id, $abundance) = each %$abundanceHash) {
      my $relative_abundance = $abundance / ($total_counts->{$sample_id});
      print OUT "$otu_id\t$abundance\t$relative_abundance\n";
    }
  }
  return ($ordered_samples, $ordered_file_names,$data_hash,  $total_counts);
}

1;
