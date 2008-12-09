package ApiCommonData::Load::WorkflowSteps::CreateEpitopeMapFile;

@ISA = (ApiCommonData::Load::WorkflowSteps::WorkflowStep);

use strict;
use ApiCommonData::Load::WorkflowSteps::WorkflowStep;

sub run {
    my ($self, $test) = @_;

    my $ncbiBlastPath = $self->getConfig('ncbiBlastPath');
    my $inputDirRelativeToDownloadsDir = $self->getParamValue('inputDirRelativeToDownloadsDir');
    my $proteinsFile = $self->getParamValue('proteinsFile');
    my $blastDbDir = $self->getParamValue('blastDbDir');
    my $organismTwoLetterAbbrev = $self->getParamValue('organismTwoLetterAbbrev');
    my $outputDir = $self->getParamValue('outputDir');
    my $idRegex = $self->getParamValue('idRegex');

    my $localDataDir = $self->getLocalDataDir();
    my $downloadDir = $self->getGlobalConfig('downloadDir');

    my $cmd = "createEpitopeMappingFile  --ncbiBlastPath $ncbiBlastPath --inputDir $downloadDir/$inputDirRelativeToDownloadsDir --queryDir $localDataDir/$proteinsFile --outputDir $localDataDir/$outputDir --blastDatabase $blastDbDir --idRegex '$idRegex'";
    $cmd .= " --speciesKey $organismTwoLetterAbbrev" if ($organismTwoLetterAbbrev);
    if ($test) {
      $self->testInputFile('proteinsFile', "$localDataDir/$proteinsFile");
      $self->testInputFile('inputDirRelativeToDownloadsDir', "$downloadDir/$inputDirRelativeToDownloadsDir");
    }

    $self->runCmd($test,$cmd);
}

sub getParamsDeclaration {
    return ('inputDirRelativeToDownloadsDir',
            'blastDbDir',
            'organismTwoLetterAbbrev',
            'proteinsFile',
            'outputDir'
           );
}


sub getConfigDeclaration {
    return (
            # [name, default, description]
              ['ncbiBlastPath', "", ""]
           );
}

sub getDocumentation {
}

sub restart {
}

sub undo {
}
