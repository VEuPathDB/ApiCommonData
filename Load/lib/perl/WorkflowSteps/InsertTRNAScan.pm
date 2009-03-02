package ApiCommonData::Load::WorkflowSteps::InsertTRNAScan;

@ISA = (ApiCommonData::Load::WorkflowSteps::WorkflowStep);
use strict;
use ApiCommonData::Load::WorkflowSteps::WorkflowStep;

sub run {
  my ($self, $test, $undo) = @_;

  # get parameters
  my $inputFile = $self->getParamValue('inputFile');

  my $genomeExtDbRlsSpec = $self->getParamValue('genomeExtDbRlsSpec');

  my $tRNAExtDbRlsSpec = $self->getParamValue('tRNAExtDbRlsSpec');

  my $soVersion = $self->getParamValue('soVersion');

  my $localDataDir = $self->getLocalDataDir();

  my ($genomeExtDbName,$genomeExtDbVersion)=$self->getExtDbInfo($test,$genomeExtDbRlsSpec);

  my ($tRNAExtDbName,$tRNAExtDbVersion)=$self->getExtDbInfo($test,$tRNAExtDbRlsSpec);

  my $args = "--data_file $inputFile --scanDbName '$tRNAExtDbName' --scanDbVer '$tRNAExtDbVersion' --genomeDbName '$genomeExtDbName' --genomeDbVer '$genomeExtDbVersion' --soVersion '$soVersion'";
    if ($test) {
      $self->testInputFile('inputFile', "$localDataDir/$inputFile");
    }

   $self->runPlugin($test, $undo, "ApiCommonData::Load::Plugin::LoadTRNAScan", $args);


}
sub getParamsDeclaration {
  return (
          'inputFile',
          'genomeExtDbRlsSpec',
          'tRNAExtDbRlsSpec',
	  'soVersion',
         );
}

sub getConfigDeclaration {
  return (
         # [name, default, description]
         # ['', '', ''],
         );
}

