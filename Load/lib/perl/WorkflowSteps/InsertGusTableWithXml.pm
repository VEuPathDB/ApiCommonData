package ApiCommonData::Load::WorkflowSteps::InsertGusTableWithXml;

@ISA = (ApiCommonData::Load::WorkflowSteps::WorkflowStep);

use strict;
use ApiCommonData::Load::WorkflowSteps::WorkflowStep;


sub run {
  my ($self, $test) = @_;

  my $xmlFile = $self->getParamValue('xmlFileRelativeToProjectHomeDir');

  my $gusTable = $self->getParamValue('gusTable');

  my $args = "--filename $xmlFile";

  self->runPlugin( "GUS::Supported::Plugin::LoadGusXml", $args);

}


sub restart {
}

sub undo {

}

sub getConfigDeclaration {
  my @properties = 
    (
     # [name, default, description]
    );
  return @properties;
}

sub getParamDeclaration {
  my @properties = 
    (
     ['xmlFile'],
     ['gusTable'],
    );
  return @properties;
}

sub getDocumentation {
}
