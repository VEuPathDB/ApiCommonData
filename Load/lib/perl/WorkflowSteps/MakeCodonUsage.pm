package ApiCommonData::Load::WorkflowSteps::MakeCondonUsage;

@ISA = (ApiCommonData::Load::WorkflowSteps::WorkflowStep);

use strict;
use ApiCommonData::Load::WorkflowSteps::WorkflowStep;


sub run {
    my ($self, $test) = @_;

    # get parameters
    my $inputFile = $self->getParamValue('inputFile');
    my $outputFile = $self->getParamValue('outputFile');

    my $localDataDir = $self->getLocalDataDir();

    my $cmd = "makeCodonUsage --infile $localDataDir/$inputFile --outfile $localDataDir/$outputFile";

    if ($test) {
      $self->testInputFile('inputFile', "$localDataDir/$inputFile");
      $self->runCmd(0,"echo test > $localDataDir/$outputFile");
    }
    $self->runCmd($test,$cmd);
}


sub getParamsDeclaration {
    return ('inputFile',
            'outputFile',
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
