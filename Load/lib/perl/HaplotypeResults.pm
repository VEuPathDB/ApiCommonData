package ApiCommonData::Load::HaplotypeResults;
use base qw(CBIL::StudyAssayResults::DataMunger::NoSampleConfigurationProfiles);

use File::Basename;
use File::Temp qw/ tempfile /;

use Data::Dumper;

sub getProtocolName {
  return "haplotype";
}

sub writeRScript {
  my ($self, $samples) = @_;

  print Dumper $samples;

  my $inputFile = $self->getInputFile();
  my $outputFile = $self->getOutputFile();

  my $inputFileBase = basename($inputFile);

  my ($rfh, $rFile) = tempfile();

  my $rString = <<RString;

source("$ENV{GUS_HOME}/lib/R/StudyAssayResults/profile_functions.R");

dat = read.table("$inputFile", header=T, sep="\\t", check.names=FALSE);

dat.samples = list();
$samples
#-----------------------------------------------------------------------
### Here we make individual files
### Header names match gus4 results tables

  samplesDir = ".$outputFile";
  dir.create(samplesDir);

  for(i in 1:ncol(dat)) {
   sampleId = colnames(dat)[i];

   sample = as.matrix(dat[,i]);
   colnames(sample)= c("value");

   header = as.matrix(dat[,1]);

   write.table(sample, file=paste(samplesDir, "/", sampleId, sep=""),quote=F,sep="\\t",row.names=header, col.names=NA);
 }

quit("no");
RString

  print $rfh $rString;

  close $rfh;

  return $rFile;
}


1;

