package ApiCommonData::Load::WorkflowSteps::CopyAndCatIedbFiles;

@ISA = (ApiCommonData::Load::WorkflowSteps::WorkflowStep);

use strict;
use ApiCommonData::Load::WorkflowSteps::WorkflowStep;

sub run {
    my ($self, $test) = @_;


    my $inputDirRelativeToDownloadsDir = $self->getParamValue('inputDirRelativeToDownloadsDir');
    my $organismName = $self->getParamValue('organismName');
    my $outputDir = $self->getParamValue('outputDir');


    my $localDataDir = $self->getLocalDataDir();
    my $downloadDir = $self->getGlobalConfig('downloadDir');

    my $inputDir="$downloadDir/$inputDirRelativeToDownloadsDir";
    my $cmd = "cat";
    my @inputFileNames = $self->getInputFiles($test,$inputDir,$organismName);
 
    if (scalar @inputFileNames==0){
	die "No input files. Please check inputDir: $inputDir\n";
    }else {
	$cmd .= join (" " ,@inputFileNames);
    }

   $cmd .= " >$localDataDir/$outputDir/IEDBExport.txt";

    if ($test) {
      $self->testInputFile('inputDir', "$inputDir");
      $self->testInputFile('outputDir', "$localDataDir/$outputDir");
    }

    $self->runCmd($test,$cmd);
}

sub getParamsDeclaration {
    return ('inputDirRelativeToDownloadsDir',
            'organismName',
            'outputDir'
           );
}


sub getConfigDeclaration {
    return (
            # [name, default, description]
           );
}

sub getDocumentation {
}

sub restart {
}

sub undo {
}
