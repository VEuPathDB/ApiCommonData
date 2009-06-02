package ApiCommonData::Load::WorkflowSteps::LoadNrdbXrefs;

@ISA = (ApiCommonData::Load::WorkflowSteps::WorkflowStep);
use strict;
use ApiCommonData::Load::WorkflowSteps::WorkflowStep;

sub run {
  my ($self, $test, $undo) = @_;

  # get parameters
  my $xrefsFile = $self->getParamValue('xrefsFile');

  my $localDataDir = $self->getLocalDataDir();

  my $args = "--DbRefMappingFile '$localDataDir/$xrefsFile' --columnSpec \"secondary_identifier,primary_identifier\"";

    if ($test) {
      $self->testInputFile('xrefsFile', "$localDataDir/$xrefsFile");
    }

   $self->runPlugin($test, $undo, "ApiCommonData::Load::Plugin::InsertNrdbXrefs", $args);


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



##this step loads the results of mapping an NR protein record to an annotated protein based on their sequences
##the protein gi numbers and source_ids from the nrdb file record are inserted into sres.dbref
##and are linked via dots.dbrefnafeature rows to the dots.genefeature row corresponding to the annotated protein
##need to avoid mapping proteins (from nr record)  from organisms in the same project
##will alternative splicing cause a problem with this?

