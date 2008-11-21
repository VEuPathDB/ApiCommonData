package ApiCommonData::Load::WorkflowSteps::InsertAASeqMWMinMax;

@ISA = (ApiCommonData::Load::WorkflowSteps::WorkflowStep);

use strict;
use ApiCommonData::Load::WorkflowSteps::WorkflowStep;


sub run {
  my ($self, $test) = @_;

  my $extDbRlsSpec = $self->getParamValue('genomeExtDbRlsSpec');
  my $table = $self->getParamValue('table');

  my ($extDbName, $extDbRlsVer) = $self->getExtDbInfo($extDbRlsSpec);

  my $args = "--extDbRlsName '$extDbName' --extDbRlsVer '$extDbRlsVer' --seqTable $table";

  $self->runPlugin($test, "GUS::Supported::Plugin::CalculateAASeqMolWtMinMax",$args);

}

sub getParamsDeclaration {
  return (
	  'genomeExtDbRlsSpec',
	  'table',
	 );
}

sub getConfigDeclaration {
  return (
	 );
}

sub restart {
}

sub undo {

}

sub getDocumentation {
}
