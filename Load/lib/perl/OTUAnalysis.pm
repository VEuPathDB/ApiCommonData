package ApiCommonData::Load::OTUAnalysis;
use base qw(CBIL::StudyAssayResults::DataMunger::Loadable);

use strict;

use CBIL::StudyAssayResults::Error;
use CBIL::StudyAssayResults::Utils;

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

  #perl version requires unique otu_ids, which is not the case for taxon strings
  #my ($samples, $fileNames, $dataHash,  $totalCounts) = $self->parseOtuFile($dataFile, $output_dir);
  my ($samples, $fileNames, $otuRFile) = $self->parseOtuFileR($dataFile, $output_dir);
  $self->runR($otuRFile);

  $self->setNames($samples);
  $self->setFileNames($fileNames);

  $self->setTechnologyType('OTU');
  my $emptyArrayRef = [];
  my %samplesHash =  map { $_ => $emptyArrayRef } @$samples;
  # my $samplesHash = $self->groupListHashRef($samples);

  $self->setInputProtocolAppNodesHash(\%samplesHash);
  $self->createConfigFile();

  # foreach my $sampleName (keys %samplesHash) {

  #   my $alphaDiversityStats = ApiCommonData::Load::AlphaDiversityStats->new({sampleName => $sampleName,
  #                                                                            inputs => [$sampleName],
  #                                                                            dataHash => $dataHash->{$sampleName},
  #                                                                            rawCount => $totalCounts->{$sampleName},
  #                                                                            mainDirectory => $self->getMainDirectory,
  #                                                                            profileSetName => $self->getProfileSetName(),
  #                                                                            samplesHash => \%samplesHash,
  #                                                                            suffix => '_alpha_diversity.tab'});
  #   $alphaDiversityStats->setProtocolName("alpha_diversity");
  #   $alphaDiversityStats->setDisplaySuffix(" [alpha_diversity]");
  #   $alphaDiversityStats->setTechnologyType($self->getTechnologyType());
	
  #   $alphaDiversityStats->munge();
  # }

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
#source("$ENV{GUS_HOME}/lib/R/StudyAssayResults/parse_biom.R");
library(biomformat)
biom.obj = read_biom(file_input);

#enforces a specific organization of taxonomy in metadata list in input file
assignTaxaAsID <- function(x) {

        kingdom <- x[["metadata"]][["superkingdom"]]
        phylum <- x[["metadata"]][["phylum"]]
        class <- x[["metadata"]][["class"]]
        order <- x[["metadata"]][["order"]]
        family <- x[["metadata"]][["family"]]
        genus <- x[["metadata"]][["genus"]]
        species <- x[["metadata"]][["species"]]

        #TODO figure out if there are null or na vals etc and make sure they are handled right
        if (is.null(phylum) | length(phylum) == 0) {
          taxaString <- "drop"
        } else {
          taxaString <- paste0("k__", kingdom, "; p__", phylum, "; c__", class, ": o__", order, "; f__", family, "; g__", genus, "; s__", species)
        }
        x <- modifyList(x, list(id = taxaString))
}

otu=data.frame(biom.obj\$data);
otu=data.frame(t(otu));

#if colnames auto-generated then replace with actual names from metadata
if (all(substring(colnames(otu),1,1) == "X")) {
  colIDs <- unlist(lapply(biom.obj\$columns, "[[", "id"))
  colIDs <- gsub("'", "", colIDs)
  colnames(otu) <- colIDs
}

ID <- unlist(lapply(biom.obj\$rows, "[[", "id"));

#attempt to get IDs from taxon strings in metadata
taxaIdList <- lapply(biom.obj\$rows, assignTaxaAsID)
taxaID <- unlist(lapply(taxaIdList, "[[", "id"))
taxaID <- gsub("'", "", taxaID)
if (!all(taxaID == "drop")) {
  ID <- taxaID
}

otu = cbind(ID,otu)
otu <- otu[!(otu\$ID=="drop"),]
write.table(otu, file=file_output, quote = FALSE, sep ="\t", row.names=FALSE);



RString
  print RCODE $rString;

  close RCODE;

  return $rFile;


}

sub parseOtuFileR {
  my ($self, $dataFile, $output_dir) = @_;

  open (OTU, "<$dataFile");

  my $header = <OTU>;
  $header=~s/\n|\r//g;
  my @sample_ids = split("\t",$header);
  shift @sample_ids;

  close OTU;

  my $ordered_samples = [];
  my $ordered_file_names = [];

  for my $sample_id (@sample_ids) {
    push (@$ordered_samples, $sample_id);
    my $outputFile = $self->getOutputFile();
    push (@$ordered_file_names, ".".$outputFile."/".$sample_id)
  }

  my ($fh, $rFile) = tempfile(DIR => "/tmp/", suffix=>".R");

  open(RCODE, "> $rFile") or die "Cannot open $rFile for writing:$!";

  my $rString = <<RString;

  library(data.table)
  
  dt <- fread("$dataFile", header=TRUE, na.strings = c(NA, "NA"))
  samples <- colnames(dt)[2:length(dt)]
  idCol <- colnames(dt)[1]

  for (sample in samples) {
    dtSample <- dt[, c(idCol, sample), with=FALSE][!is.na(dt[[sample]])]
    sum <- sum(dtSample[[sample]])
    dtSample <- dtSample[dtSample[[sample]] != 0,]
    dtSample <- dtSample[!is.na(dtSample[[sample]]),]
    dtSample\$rel_abun <- dtSample[[sample]]/sum
    colnames(dtSample) <- c("ID", "raw_count", "relative_abundance")
    write.table(dtSample, file=paste0("$output_dir", sample), quote = FALSE, sep ="\t", row.names=FALSE)
  }

RString
  print RCODE $rString;

  close RCODE;

  return ($ordered_samples, $ordered_file_names, $rFile);
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
    chomp $line;
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
