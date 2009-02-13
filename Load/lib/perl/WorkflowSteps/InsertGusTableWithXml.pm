package ApiCommonData::Load::WorkflowSteps::InsertGusTableWithXml;

@ISA = (ApiCommonData::Load::WorkflowSteps::WorkflowStep);

use strict;
use ApiCommonData::Load::WorkflowSteps::WorkflowStep;


sub run {
  my ($self, $test, $undo) = @_;

  my $xmlFile = $self->getParamValue('xmlFileRelativeToGusHomeDir');
  my $gusTable = $self->getParamValue('gusTable');

  my $gusHome = $self->getGlobalConfig('gusHome');

  my $args = "--filename $gusHome/$xmlFile --tableName $gusTable";

  if ($test) {
      $self->testInputFile('xmlFile', "$gusHome/$xmlFile");
  }
  $self->runPlugin($test, $undo, "GUS::Supported::Plugin::LoadGusXml", $args);

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


