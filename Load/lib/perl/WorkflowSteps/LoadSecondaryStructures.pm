package ApiCommonData::Load::WorkflowSteps::LoadSecondaryStructures;

@ISA = (ApiCommonData::Load::WorkflowSteps::WorkflowStep);

use strict;
use ApiCommonData::Load::WorkflowSteps::WorkflowStep;


sub run {
    my ($self, $test, $undo) = @_;

    my $algName = $self->getParamValue('algName');
    my $inputDir = $self->getParamValue('inputDir');

    my $localDataDir = $self->getLocalDataDir();

    my $algImpVer = "dontcare";
    my $algInvStart = "2000-01-01";
    my $algInvEnd = "2000-01-01";
    my $args = "--predAlgName $algName  --predAlgImpVersion $algImpVer --predAlgInvStart $algInvStart --predAlgInvEnd $algInvEnd --directory $localDataDir/$inputDir";

    if ($test) {
      $self->testInputFile('inputDir', "$localDataDir/$inputDir");
    }

   $self->runPlugin($test,$undo, "GUS::Supported::Plugin::InsertSecondaryStructure", $args);

}


sub getParamsDeclaration {
    return ('algName',
            'inputDir',
           );
}


sub getConfigDeclaration {
    return (
            # [name, default, description]
           );
}



