package ApiCommonData::Load::WorkflowSteps::InsertGusTableWithXml;

@ISA = (ApiCommonData::Load::WorkflowSteps::WorkflowStep);

use strict;
use ApiCommonData::Load::WorkflowSteps::WorkflowStep;


sub run {
  my ($self, $test) = @_;

  my $xmlFile = $self->getParamValue('xmlFileRelativeToGusHomeDir');
  my $gusTable = $self->getParamValue('gusTable');

  my $gusHome = $self->getGlobalConfig('gusHome');

  my $args = "--filename $gusHome/$xmlFile";

  $self->runPlugin($test, "GUS::Supported::Plugin::LoadGusXml", $args);

}

sub getParamsDeclaration {
  return (
	  'xmlFile',
	  'gusTable',
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
