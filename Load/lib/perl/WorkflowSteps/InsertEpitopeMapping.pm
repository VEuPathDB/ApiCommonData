package ApiCommonData::Load::WorkflowSteps::InsertEpitopeMapping;

@ISA = (ApiCommonData::Load::WorkflowSteps::WorkflowStep);

use strict;
use ApiCommonData::Load::WorkflowSteps::WorkflowStep;

sub run {
  my ($self, $test) = @_;

  my $inputFile = $self->getParamValue('inputFile');
  my $epiExtDbSpecs = $self->getParamValue('iedbExtDbRlsSpec');
  my $seqExtDbSpecs = $self->getParamValue('genomeExtDbRlsSpec');

  my $localDataDir = $self->getLocalDataDir();

  my $args =" --inputFile $localDataDir/$inputFile --extDbRelSpec '$epiExtDbSpecs' --seqExtDbRelSpec '$seqExtDbSpecs'";

    if ($test) {
      $self->testInputFile('inputFile', "$localDataDir/$inputFile");
    }

    $self->runPlugin ($test,"ApiCommonData::Load::Plugin::InsertEpitopeFeature","$args");


}


sub getParamsDeclaration {
  return ('inputFile',
	  'iedbExtDbRlsSpec',
	  'genomeExtDbRlsSpec'
	 );
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

