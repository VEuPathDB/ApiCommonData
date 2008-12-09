package ApiCommonData::Load::WorkflowSteps::InsertOrfFile;

@ISA = (ApiCommonData::Load::WorkflowSteps::WorkflowStep);

use strict;
use ApiCommonData::Load::WorkflowSteps::WorkflowStep;


sub run {
  my ($self, $test) = @_;

  my $inputFile = $self->getParamValue('inputFile');
  my $genomeExtDbRlsSpec = $self->getParamValue('genomeExtDbRlsSpec');
  my $substepClass = $self->getParamValue('substepClass');
  my $defaultOrg = $self->getParamValue('defaultOrg');
  my $isfMappingFileRelToGusHome = $self->getParamValue('isfMappingFileRelToGusHome');
  my $soVersion = $self->getParamValue('soVersion');

  my $gusHome = $self->getGlobalConfig('gusHome');

  my ($extDbName,$extDbRlsVer) = $self->getExtDbInfo($genomeExtDbRlsSpec);

  my $localDataDir = $self->getLocalDataDir();

  my $args = <<"EOF";
--extDbName '$extDbName'  \\
--extDbRlsVer '$extDbRlsVer' \\
--mapFile $gusHome/$isfMappingFileRelToGusHome \\
--inputFileOrDir $localDataDir/$inputFile \\
--fileFormat gff3   \\
--seqSoTerm ORF  \\
--soCvsVersion $soVersion \\
--naSequenceSubclass $substepClass \\
EOF
  if ($defaultOrg) {
    $args .= "--defaultOrganism '$defaultOrg'";
  }

  if ($test) {
    $self->testInputFile('inputFile', "$localDataDir/$inputFile");
  }

  $self->runPlugin($test, "GUS::Supported::Plugin::InsertSequenceFeatures", $args);
}


sub getParamsDeclaration {
  return (
	  'inputFile',
	  'genomeExtDbRlsSpec',
	  'substepClass',
	  'defaultOrg',
	  'isfMappingFileRelToGusHome',
	  'soVersion',
	 );
}

sub getConfigDeclaration {
  return (
	  # [name, default, description]
	 );
}

sub restart {
}

sub undo {

}

sub getDocumentation {
}
