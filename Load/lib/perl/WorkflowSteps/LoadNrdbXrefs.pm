package ApiCommonData::Load::WorkflowSteps::LoadNrdbXrefs;

@ISA = (ApiCommonData::Load::WorkflowSteps::WorkflowStep);
use strict;
use ApiCommonData::Load::WorkflowSteps::WorkflowStep;

sub run {
  my ($self, $test) = @_;

  # get parameters
  my $xrefsFile = $self->getParamValue('xrefsFile');
  my $dbAbbrevList = $self->getParamValue('dbAbbrevList');
  my $nrdbExtDbRlsSpec = $self->getParamValue('nrdbExtDbRlsSpec');


}

sub getParamsDeclaration {
  return (
          'xrefsFile',
          'dbAbbrevList',
          'nrdbVersion',
         );
}

sub getConfigDeclaration {
  return (
         # [name, default, description]
         # ['', '', ''],
         );
}

sub restart {
}

sub undo {

}

sub getDocumentation {
}
