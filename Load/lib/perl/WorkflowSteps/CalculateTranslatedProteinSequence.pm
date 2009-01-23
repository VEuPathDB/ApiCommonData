package ApiCommonData::Load::WorkflowSteps::CalculateTranslatedProteinSequence;

@ISA = (ApiCommonData::Load::WorkflowSteps::WorkflowStep);

use strict;
use ApiCommonData::Load::WorkflowSteps::WorkflowStep;

sub run {
  my ($self, $test) = @_;

  my $extDbRlsSpec = $self->getParamValue('genomeExtDbRlsSpec');
  my $soVersion = $self->getParamValue('soVersion');

  my ($extDbName, $extDbVer) = $self->getExtDbInfo($test,$extDbRlsSpec);

  my $args = "--sqlVerbose --extDbRlsName '$extDbName' --extDbRlsVer '$extDbVer' --soCvsVersion $soVersion";

  $self->runPlugin($test, "GUS::Supported::Plugin::CalculateTranslatedAASequences", $args);

}

sub getParamsDeclaration {
  return ('genomeExtDbRlsSpec',
	  'soVersion');
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

