package ApiCommonData::Load::WorkflowSteps::InsertBlastSimilarities;

@ISA = (ApiCommonData::Load::WorkflowSteps::WorkflowStep);

use strict;
use ApiCommonData::Load::WorkflowSteps::WorkflowStep;

sub run {
  my ($self, $test) = @_;

  my $inputFile = $self->getParamValue('inputFile');
  my $queryTable = $self->getParamValue('queryTable');
  my $queryTableSrcIdCol = $self->getParamValue('queryTableSrcIdCol');
  my $queryExtDbRlsSpec = $self->getParamValue('queryExtDbRlsSpec');
  my $subjectTable = $self->getParamValue('subjectTable');
  my $subjectTableSrcIdCol = $self->getParamValue('subjectTableSrcIdCol');
  my $subjectExtDbRlsSpec = $self->getParamValue('subjectExtDbRlsSpec');
  my $options = $self->getParamValue('options');

  my $localDataDir = $self->getLocalDataDir();

  my $queryColArg = "--queryTableSrcIdCol $queryTableSrcIdCol" if $queryTableSrcIdCol;

  my $subjectColArg = "--subjectTableSrcIdCol $subjectTableSrcIdCol" if $subjectTableSrcIdCol;

  my $queryExtDbArg = "";
  if ($queryExtDbRlsSpec) {
    my ($queryDbName, $queryDbRlsVer) = $self->getExtDbInfo($queryExtDbRlsSpec);
    $queryExtDbArg = " --queryExtDbName '$queryDbName' --queryExtDbRlsVer '$queryDbRlsVer'";
  }

  my $subjectExtDbArg = "";
  if ($subjectExtDbRlsSpec) {
    my ($subjectDbName, $subjectDbRlsVer) = $self->getExtDbInfo($subjectExtDbRlsSpec);
    $subjectExtDbArg = " --subjectExtDbName '$subjectDbName' --subjectExtDbRlsVer '$subjectDbRlsVer'";
  }

  my $args = "--file $localDataDir/$inputFile --queryTable $queryTable $queryColArg $queryExtDbArg --subjectTable $subjectTable $subjectColArg $subjectExtDbArg $options";

  $self->runPlugin($test, "GUS::Supported::Plugin::InsertBlastSimilarities", $args);
}

sub getParamsDeclaration {
  return (
	  'inputFile',
	  'queryTable',
	  'queryTableSrcIdCol',
	  'queryExtDbRlsSpec',
	  'subjectTable',
	  'subjectTableSrcIdCol',
	  'subjectExtDbRlsSpec',
	  'options',
	);
}

sub getConfigurationDeclaration {
  return ();
}

sub restart {
}

sub undo {

}

sub getDocumentation {
}
