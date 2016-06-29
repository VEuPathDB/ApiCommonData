package ApiCommonData::Load::OTUAnalysis;
use base qw(CBIL::TranscriptExpression::DataMunger::Loadable);

use strict;

use CBIL::TranscriptExpression::Error;
use CBIL::TranscriptExpression::Utils;

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

  if ($inputFile =~/.biom$/) {
    ($dataFile,$mappingFile) = parseBiomFile($self->mappingFile); 
  }

  $self->setProtocolName('otu_analysis');
  my ($samples, $fileNames) = $self->parseOtuFile($dataFile);
    
  $self->setNames($samples);
  $self->setFileNames($fileNames);
  my $samplesHash = $self->groupListHashRef($samples);

  $self->setInputProtocolAppNodesHash($samplesHash);

  $self->createConfigFile(); 
}


sub parseBiomFile {
  my ($self,$biomFile) =@_;

  my $mainDir = $self->getMainDirectory();
  my $inputFile = $self->getInputFile;
  my $outputFile = $mainDir."/".$self->getOutputFile;
 $outputFile =~s/\/\//\//;

  my $mappingFile = $self->getMappingFile;
  my $data_file;
  my $rString = <<RString;

file_input = "$inputFile";
source("$ENV{GUS_HOME}/lib/R/TranscriptExpression/parse_biom.R");

biom.obj = read_hdf5_biom(file_input);


ids <- unlist(lapply(biom.obj\$rows, "[[", "id"));
md <- as.list(lapply(lapply(biom.obj\$rows, "[[", "metadata"),"[[", "taxonomy"));
md <- lapply(md, paste, collapse="|")
df <- do.call(rbind, Map(data.frame, id=as.list(ids), taxon=md));
write.table(df, "$mappingFile, sep="\t", quote=FALSE, row.names=FALSE);

otu=data.frame(biom.obj\$data);


RString
}

sub parseOtuFile {
  my ($self, $dataFile) = @_;

  open (OTU, "<$dataFile");
  
  my $header = <OTU>;
  my @samples = split("\t",$header);
  shift @samples;
  
  my $dataHash = {};
  my $totalCounts = {};
  my $gg_id = [];
  while  (my $line = <OTU>) {
    my @cols = split ("\t",$line);
    my $gg_id = shift @cols;
    my $i = 0;
    while ($i < (scalar (@cols))) {
      unless ($cols[$i] =~/NA/i || !defined $cols[$i] || $cols[$i] ==0) {
        $dataHash->{$samples[$i]}->{$gg_id} = $cols[$i];  
        $totalCounts->{$samples[$i]} = defined $totalCounts->{$samples[$i]} ? $totalCounts->{$samples[$i]} + $cols[$i] : $cols[$i];

      }
      $i++;
    }
  }
  
  my $outputFile = $self->getOutputFile();
  my $ordered_samples = [];
  my $ordered_file_names = [];
  my $output_dir = $self->getMainDirectory()."/.".$outputFile."/";
  mkdir($output_dir) unless -d $output_dir;
  while (my ($sample_id, $relAbundanceHash) = each %$dataHash) {
    my $outputFileLocation = $output_dir.$sample_id;
    $outputFileLocation =~ s/\s/_/;
    $outputFileLocation =~ s/[\(\)]//g;
    $outputFileLocation =~ s/\/\//\//g;
    push (@$ordered_samples, $sample_id);
    push (@$ordered_file_names, $outputFileLocation);
    open (OUT, ">$outputFileLocation") or die "unable to open file $outputFileLocation: $!";
    print OUT "ID\traw_count\trelative_abundance\n";
    while (my ($gg_id, $abundance) = each %$relAbundanceHash) {
      my $relative_abundance = $abundance / ($totalCounts->{$sample_id});
      print OUT "$gg_id\t$abundance\t$relative_abundance\n";
    }

  }
  return ($ordered_samples, $ordered_file_names);
}

1;
