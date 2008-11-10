package ApiCommonData::Load::WorkflowSteps::CalculateProteinMolWt;

@ISA = (ApiCommonData::Load::WorkflowSteps::WorkflowStep);

use strict;
use ApiCommonData::Load::WorkflowSteps::WorkflowStep;


sub run {
  my ($self, $test) = @_;

  my $table = $self->getParamValue('table');
  my $extDbRlsSpec = $self->getParamValue('genomeExtDbRlsSpec');

  my ($extDbName, $extDbRlsVer) = $self->getExtDbRlsInfo($extDbRlsSpec);

  my $args = "--extDbRlsName '$extDbName' --extDbRlsVer '$extDbRlsVer' --seqTable $table";

  $self->runPlugin($test, "GUS::Supported::Plugin::CalculateAASequenceMolWt", $args);

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
      'table',
     ]
    );
  return @properties;
}

sub getDocumentation {
}

sub restart {
}

sub undo {

}


