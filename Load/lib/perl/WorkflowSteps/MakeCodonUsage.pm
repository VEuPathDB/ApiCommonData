package ApiCommonData::Load::WorkflowSteps::MakeCodonUsage;

@ISA = (ApiCommonData::Load::WorkflowSteps::WorkflowStep);

use strict;
use ApiCommonData::Load::WorkflowSteps::WorkflowStep;


sub run {
    my ($self, $test, $undo) = @_;

    # get parameters
    my $inputFile = $self->getParamValue('inputFile');
    my $outputFile = $self->getParamValue('outputFile');

    my $apiSiteFilesDir = $self->getGlobalConfig('apiSiteFilesDir');

    my $cmd = <<"EOF";
      makeCodonUsage 
        --outputFile $apiSiteFilesDir/$outputFile \\
        --inputFile  $apiSiteFilesDir/$inputFile \\
        --verbose
EOF


    if ($test) {
      $self->testInputFile('inputFile', "$apiSiteFilesDir/$inputFile");
      $self->runCmd(0,"echo test > $apiSiteFilesDir/$outputFile");
    }

    if ($undo) {
      $self->runCmd(0, "rm -f $apiSiteFilesDir/$outputFile");
    } else {
      $self->runCmd($test,$cmd);
    }
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


