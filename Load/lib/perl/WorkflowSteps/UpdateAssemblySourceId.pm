package ApiCommonData::Load::WorkflowSteps::UpdateAssemblySourceId;

@ISA = (GUS::Workflow::WorkflowStepInvoker);

use strict;
use GUS::Workflow::WorkflowStepInvoker;

sub run {

  my ($self, $test) = @_;

  my $taxonId = $self->getTaxonId($self->getParamValue('ncbiTaxonId'));

  my $organismTwoLetterAbbrev = $self->getParamValue('organismTwoLetterAbbrev');

  my $cmd = "updateAssSourceIdFromPK --prefix '${organismTwoLetterAbbrev}DT.' --suffix '.tmp' --TaxonId $taxonId";  

  $self->runCmd($test, $cmd);
 
}

sub restart {
}

sub undo {

}

sub getConfigDeclaration {
  my @properties = 
    (
     # [name, default, description]
     ['ncbiTaxonId', "", ""],
     ['organismTwoLetterAbbrev', "", ""],
    );
  return @properties;
}

sub getParamDeclaration {
  my @properties = 
    (
     ['ncbiTaxonId'],
     ['organismTwoLetterAbbrev'],
    );
  return @properties;
}

sub getDocumentation {
}
