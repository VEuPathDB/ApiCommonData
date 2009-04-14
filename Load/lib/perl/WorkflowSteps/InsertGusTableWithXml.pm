package ApiCommonData::Load::WorkflowSteps::InsertGusTableWithXml;

@ISA = (ApiCommonData::Load::WorkflowSteps::WorkflowStep);

use strict;
use ApiCommonData::Load::WorkflowSteps::WorkflowStep;


sub run {
  my ($self, $test, $undo) = @_;

  my $xmlFile = $self->getParamValue('xmlFileRelativeToGusHomeDir');
  my $gusTable = $self->getParamValue('gusTable');

  my $gusHome = $self->getGlobalConfig('gusHome');

  my $undoArgs = "--undoTables $gusTable";

  my $args = "--filename $gusHome/$xmlFile";

  if ($undo){
      $self->runPlugin($test, $undo, "GUS::Supported::Plugin::LoadGusXml", $undoArgs);
  }else{
      if ($test) {
	  $self->testInputFile('xmlFile', "$gusHome/$xmlFile");
      }else{
	  $self->runPlugin($test, $undo, "GUS::Supported::Plugin::LoadGusXml", $args);
      }
  }

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


