package ApiCommonData::Load::WorkflowSteps::InsertEpitopeMapping;

@ISA = (ApiCommonData::Load::WorkflowSteps::WorkflowStep);

use strict;
use ApiCommonData::Load::WorkflowSteps::WorkflowStep;

sub run {
  my ($self, $test) = @_;

  my $inputDir = $self->getParamValue('inputDir');
  my $epiExtDbSpecs = $self->getParamValue('iedbExtDbRlsSpec');
  my $seqExtDbSpecs = $self->getParamValue('genomeExtDbRlsSpec');

  my $localDataDir = $self->getLocalDataDir();

  my @inputFiles;
 # @inputFiles = &_getInputFiles($localDataDir/$inputDir);

  foreach my $file (@inputFiles) {

    my $args = " --inputFile $file --extDbRelSpec '$epiExtDbSpecs' --seqExtDbRelSpec '$seqExtDbSpecs'";

    if ($test) {
      $self->testInputFile('inputDir', "$localDataDir/$inputDir");
    }

    $self->runPlugin ($test,"ApiCommonData::Load::Plugin::InsertEpitopeFeature","$args");
  }

}


sub getParamsDeclaration {
  return ('inputDir',
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

