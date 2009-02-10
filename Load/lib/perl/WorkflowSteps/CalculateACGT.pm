package ApiCommonData::Load::WorkflowSteps::CalculateACGT;

@ISA = (ApiCommonData::Load::WorkflowSteps::WorkflowStep);

use strict;
use ApiCommonData::Load::WorkflowSteps::WorkflowStep;


sub run {
  my ($self, $test, $undo) = @_;

  my $nullsOnly = $self->getParamValue('nullsOnly') ? "--nullsOnly" : "";

  my $args = "--sqlVerbose $nullsOnly";

  $self->runPlugin($test, $undo,  "ApiCommonData::Load::Plugin::CalculateACGTContent", $args);

}

sub getParamsDeclaration {
  return ('nullsOnly',
	 );
}

sub getConfigDeclaration {
  return (
	  # [name, default, description]
	 );
}



