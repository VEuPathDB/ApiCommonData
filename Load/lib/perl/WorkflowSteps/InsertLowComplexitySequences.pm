package ApiCommonData::Load::WorkflowSteps::LoadLowComplexitySequences;

@ISA = (ApiCommonData::Load::WorkflowSteps::WorkflowStep);

use strict;
use ApiCommonData::Load::WorkflowSteps::WorkflowStep;


sub run {
  my ($self, $test) = @_;

  my $inputFile = $self->getParamValue('inputFile');
  my $genomeExtDbRlsSpec = $self->getParamValue('genomeExtDbRlsSpec'); 
  my $seqType = $self->getParamValue('seqType');
  my $mask = $self->getParamValue('mask');
  my $options = $self->getParamValue('options');

  my ($extDbName,$extDbRlsVer) = $self->getExtDbInfo($genomeExtDbRlsSpec);

  my $args = "--seqFile $inputFile --fileFormat 'fasta' --extDbName '$extDbName' --extDbVersion '$extDbRlsVer' --seqType $seqType --maskChar $mask $options";
   
  $self->runPlugin($test, "ApiCommonData::Load::Plugin::InsertLowComplexityFeature", $args);
}

sub getConfigDeclaration {
  return (
	  # [name, default, description]
	 );
}

sub getParamDeclaration {
  return (
	  'inputFile',
	  'genomeExtDbRlsSpec',
	  'mask',
	  'seqType',
	  'options',
	 );
}

sub restart {
}

sub undo {

}

sub getDocumentation {
}

