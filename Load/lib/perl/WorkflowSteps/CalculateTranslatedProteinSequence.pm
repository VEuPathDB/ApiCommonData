package ApiCommonData::Load::WorkflowSteps::CalculateTranslatedProteinSequence;

@ISA = (ApiCommonData::Load::WorkflowSteps::WorkflowStep);

use strict;
use ApiCommonData::Load::WorkflowSteps::WorkflowStep;

sub run {
  my ($self, $test) = @_;

  my $extDbRlsSpec = $self->getParamValue('genomeExtDbRlsSpec');
  my $soVersion = $self->getParamValue('soVersion');

  my ($extDbName, $extDbVer) = $self->getExtDbRlsInfo($extDbRlsSpec);

  my $args = "--sqlVerbose --extDbRlsName '$extDbName' --extDbRlsVer '$extDbVer' --soCvsVersion $soVersion";

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

