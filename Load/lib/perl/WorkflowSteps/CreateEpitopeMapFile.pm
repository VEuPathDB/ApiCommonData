package ApiCommonData::Load::WorkflowSteps::CreateEpitopeMapFile;

@ISA = (ApiCommonData::Load::WorkflowSteps::WorkflowStep);

use strict;
use ApiCommonData::Load::WorkflowSteps::WorkflowStep;

sub run {
    my ($self, $test) = @_;


    my $inputDir = $self->getParamValue('inputDir');
    my $queryDir = $self->getParamValue('queryDir');
    my $proteinsFile = $self->getParamValue('proteinsFile');
    my $blastDbDir = $self->getParamValue('blastDbDir');
    my $outputDir = $self->getParamValue('outputDir');
    my $idRegex = $self->getParamValue('idRegex');

    my $localDataDir = $self->getLocalDataDir();
    my $downloadDir = $self->getGlobalConfig('downloadDir');
    my $ncbiBlastPath = $self->getConfig('ncbiBlastPath');

    my $cmd = "createEpitopeMappingFileWorkflow  --ncbiBlastPath $ncbiBlastPath --inputDir $localDataDir/$inputDir --queryDir $localDataDir/$queryDir --outputDir $localDataDir/$outputDir --blastDatabase $localDataDir/$blastDbDir/AnnotatedProteins.fsa --idRegex '$idRegex' --subjectFile $localDataDir/$proteinsFile";

    if ($test) {
      $self->testInputFile('proteinsFile', "$localDataDir/$proteinsFile");
      $self->testInputFile('inputDir', "$localDataDir/$inputDir");
    }

    $self->runCmd($test,$cmd);
}

sub getParamsDeclaration {
    return ('inputDir',
            'blastDbDir',
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
