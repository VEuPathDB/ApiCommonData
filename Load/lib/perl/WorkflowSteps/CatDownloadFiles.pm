package ApiCommonData::Load::WorkflowSteps::CatDownloadFiles;

@ISA = (ApiCommonData::Load::WorkflowSteps::WorkflowStep);

use strict;
use ApiCommonData::Load::WorkflowSteps::WorkflowStep;

sub run {
    my ($self, $test, $undo) = @_;


    my $outputFileRelativeToDownloadsDir = $self->getParamValue('outputFileRelativeToDownloadsDir');
    my $inputDirRelativeToDownloadsDir = $self->getParamValue('inputDirRelativeToDownloadsDir');
    my $inputFileNameRegex = $self->getParamValue('inputFileNameRegex');
    my $inputFileNameExtension = $self->getParamValue('inputFileNameExtension');
    my $apiSiteFilesDir = $self->getGlobalConfig('apiSiteFilesDir');

    my $inputDir="$apiSiteFilesDir/$inputDirRelativeToDownloadsDir";
    my $outputFile="$apiSiteFilesDir/$outputFileRelativeToDownloadsDir";

    my $cmd = "cat ";
    my @inputFileNames = $self->getInputFiles($test,$inputDir,$inputFileNameRegex,$inputFileNameExtension);
    my $size=scalar @inputFileNames;

    if (scalar @inputFileNames==0){
	die "No input files. Please check inputDir: $inputDir\n";
    }else {
	$cmd .= join (" " ,@inputFileNames);
    }

   $cmd .= " >$outputFile";

    if ($undo) {
      $self->runCmd(0, "rm -f $outputFile");
    } else {
    if ($test) {
      $self->testInputFile('inputDir', "$inputDir");
    }
      $self->runCmd($test, $cmd);
    }
}

sub getParamsDeclaration {
    return ('outputFileRelativeToDownloadsDir',
            'inputDirRelativeToDownloadsDir',
            'inputFileNameRegex',
	    'inputFileNameExtension',
           );
}


sub getConfigDeclaration {
    return (
            # [name, default, description]
           );
}

