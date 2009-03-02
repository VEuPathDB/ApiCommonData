package ApiCommonData::Load::WorkflowSteps::FixPsipredFileNames;

@ISA = (ApiCommonData::Load::WorkflowSteps::WorkflowStep);

use strict;
use ApiCommonData::Load::WorkflowSteps::WorkflowStep;

sub run {
    my ($self, $test, $undo) = @_;

    my $inputDir = $self->getParamValue('inputDir');
    my $outputDir = $self->getParamValue('outputDir');

    my $localDataDir = $self->getLocalDataDir();

    $self->runCmd(0,"mkdir -p $localDataDir/$outputDir");

    $self->runCmd(0,"cp -r $localDataDir/$inputDir  $localDataDir/$outputDir");

    opendir(DIR, "$localDataDir/$outputDir") || die "Can't open directory '$localDataDir/$outputDir'";

    if ($test) {
      $self->runCmd(0,"echo test > $localDataDir/$outputDir/testFile");
    }


    if ($undo) {
      $self->runCmd(0, "rm -rf $localDataDir/$outputDir");
    } else {
      my @files = readdir(DIR);
      foreach my $file (@files) {
	next if $file=~ /^\.\.?$/;  # skip . and ..
        my $original = $file;
        $file =~ s/(\S+)_(\d)/$1-$2/g;
        $self->runCmd($test, "mv $localDataDir/$outputDir/$original $localDataDir/$outputDir/$file");
      }
    }
}

sub getParamsDeclaration {
    return ('inputDir',
            'outputDir'
           );
}


sub getConfigDeclaration {
    return (
            # [name, default, description]
           );
}


