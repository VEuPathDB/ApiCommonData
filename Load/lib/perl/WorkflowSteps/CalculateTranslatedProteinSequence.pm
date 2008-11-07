package ApiCommonData::Load::WorkflowSteps::CalculateTranslatedProteinSequence;

@ISA = (GUS::Workflow::WorkflowStepInvoker);

use strict;
use GUS::Workflow::WorkflowStepInvoker;


sub run {
  my ($self, $test) = @_;

  my $extDbRlsSpec = $self->getParamValue('genomeExtDbRlsSpec');

  my ($extDbName, $extDbRlsVer) = $self->getExtDbRlsInfo($extDbRlsSpec);

  my $soVersion = $self->getParamValue('soVersion');

  my $args = "--sqlVerbose --extDbRlsName '$extDbName' --extDbRlsVer '$extDbRlsVer' --soCvsVersion $soVersion";

  $self->runPlugin($test, "GUS::Supported::Plugin::CalculateTranslatedAASequences", $args);

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
     ['genomeExtDbRlsSpec',
      'soVersion'],
    );
  return @properties;
}

sub getDocumentation {
}

sub restart {
}

sub undo {

}

