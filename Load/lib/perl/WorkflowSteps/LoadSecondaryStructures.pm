package ApiCommonData::Load::WorkflowSteps::LoadSecondaryStructures;

@ISA = (ApiCommonData::Load::WorkflowSteps::WorkflowStep);

use strict;
use ApiCommonData::Load::WorkflowSteps::WorkflowStep;


sub run {
    my ($self, $test) = @_;

    my $algName = $self->getParamValue('algName');
    my $inputDir = $self->getParamValue('inputDir');

    my $localDataDir = $self->getLocalDataDir();

    my $args = "--predAlgName $algName --directory $localDataDir/$inputDir";

    $self->runPlugin($test,"GUS::Supported::Plugin::InsertSecondaryStructure", $args);

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

sub getDocumentation {
}

sub restart {
}

sub undo {
}

