package ApiCommonData::Load::RnaSeqCounts;
use base qw(CBIL::StudyAssayResults::DataMunger::ProfileFromSeparateFiles);

use locale;
use open ":std" => ":locale";

use File::Basename;
use File::Temp qw/ tempfile /;

use strict;
use Data::Dumper;

# override from superclass since config file will not be in the same location as the input
sub getConfigFilePath {
    return $_[0]->{_config_file_path};
}

sub setConfigFilePath {
    my ($self, $mainDir) =  @_;
    my $configFileBaseName = $self->getConfigFileBaseName();
    my $configFilePath = "$mainDir/$configFileBaseName";
    $self->{_config_file_path} = $configFilePath;
}

# override from Profiles.pm
# remove all the stuff related to microarrays
# Raw and TPM counts go into one file
# Also dump out raw count matrix for EDA
sub writeRScript {
    my($self, $samples) = @_;
    print STDERR Dumper "In RnaSeqCounts\n";
    print STDERR Dumper $self;
    print STDERR Dumper $samples;

    my $inputFile = $self->getInputFile();
    my $outputFile = $self->getOutputFile();
    my $pctOutputFile = $outputFile . ".pct";
    my $stdErrOutputFile = $outputFile . ".stderr";

    my $inputFileBase = basename($inputFile);

    my ($rfh, $rFile) = tempfile();
    print STDERR Dumper $inputFile;
    print STDERR Dumper $outputFile;

    my $makeStandardError = $self->getMakeStandardError() ? "TRUE" : "FALSE";
    my $makePercentiles = $self->getMakePercentiles() ? "TRUE" : "FALSE";

    # do I need these??
    my $findMedian = $self->getFindMedian() ? "TRUE" : "FALSE";
    my $isLogged = $self->getIsLogged() ? "TRUE" : "FALSE";
    my $statistic = $self->getFindMedian() ? "median" : "average";
    #my $isTimeSeries = $self->getIsTimeSeries();
    $self->addProtocolParamValue("statistic", $statistic);
    #$self->addProtocolParamValue("isTimeSeries", $isTimeSeries);
    $self->addProtocolParamValue("isLogged", $isLogged);

    # begin R string
    my $rString = <<RString;

source("$ENV{GUS_HOME}/lib/R/StudyAssayResults/profile_functions.R");

dat = read.table("$inputFile", header=T, sep="\\t", check.names=FALSE);

dat.samples = list()
$samples
#------------------------------------------------------------------------

# write out samples
reorderedSamples = reorderAndGetColCentralVal(pl=dat.samples, df=dat, computeMedian=$findMedian);
write.table(reorderedSamples\$data, file="$outputFile", quote=F, sep="\\t", row.names=reorderedSamples\$id, col.names=NA);

# write out stderrs
if ($makeStandardError) {
    write.table(reorderedSamples\$stdErr, file="$stdErrOutputFile", quote=F, sep="\\t", row.names=reorderedSamples\$id, col.names=NA);
}

# write out percentiles
if ($makePercentiles) {
    reorderedSamples\$percentile = percentileMatrix(m=reorderedSamples\$data);
    write.table(reorderedSamples\$percentile, file="$pctOutputFile", quote=F, sep="\\t", row.names=reorderedSamples\$id, col.names=NA);
}


### Here we make individual files
### Header names match results tables

samplesDir = paste(dirname("$outputFile"), "/", ".", basename("$outputFile"), sep="");
dir.create(samplesDir)

for (i in 1:ncol(reorderedSamples\$data)) {
    sampleId = colnames(reorderedSamples\$data)[i];
    sample = as.matrix(reorderedSamples\$data[,i]);
    colnames(sample) = c("value")

    if ($makeStandardError) {
        stdErrSample = as.matrix(reorderedSamples\$stdErr[,i]);
        colnames(stdErrSample) = c("standard_error");
        sample = cbind(sample, stdErrSample);
    }

    if ($makePercentiles) {
        pctSample = as.matrix(reorderedSamples\$percentile[,i]);
        colnames(pctSample) = c("percentile_channel1");
        sample = cbind(sample, pctSample);
    }


    # Fix disallowed characters
    # spaces become underscores,  ( and ) are removed
    sampleFile = gsub(\" \", \"_\", sampleId, fixed=TRUE);
    sampleFile = gsub(\"(\", \"\", sampleFile, fixed=TRUE);
    sampleFile = gsub(\")\", \"\", sampleFile, fixed=TRUE);

    write.table(sample, file=paste(samplesDir, "/", sampleFile, sep=""), quote=F, sep="\\t", row.names=reorderedSamples\$id, col.names=NA);
}

quit("no");
RString

    binmode $rfh, ':encoding(UTF-8)';
    print $rfh $rString;
    close $rfh;

    print STDERR $rString;

    return $rFile;
}


### Use the new and munge methods from the superclass!

1;
