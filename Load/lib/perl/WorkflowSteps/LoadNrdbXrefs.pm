package ApiCommonData::Load::WorkflowSteps::LoadNrdbXrefs;

@ISA = (ApiCommonData::Load::WorkflowSteps::WorkflowStep);
use strict;
use ApiCommonData::Load::WorkflowSteps::WorkflowStep;

sub run {
  my ($self, $test) = @_;

  # get parameters
  my $xrefsFile = $self->getParamValue('xrefsFile');

  my $localDataDir = $self->getLocalDataDir();

  my $args = "--DbRefMappingFile '$localDataDir/$xrefsFile' --columnSpec \"secondary_identifier,primary_identifier\"";

    if ($test) {
      $self->testInputFile('xrefsFile', "$localDataDir/$xrefsFile");
    }

   $self->runPlugin($test,"ApiCommonData::Load::Plugin::InsertNrdbXrefs", $args);


}
sub getParamsDeclaration {
  return (
          'xrefsFile',
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
