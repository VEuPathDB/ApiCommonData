package ApiCommonData::Load::Steps::WorkflowSteps::LoadBlastSimilarities;

@ISA = (GUS::Pipeline::WorkflowStep);

sub run {
  my ($self) = @_;

  my $inputFile = $self->getParamValue('inputFile');
  my $queryTable = $self->getParamValue('queryTable');
  my $queryTableIdCol = $self->getParamValue('queryTableSrcIdCol');
  my $queryExtDbRlsSpec = $self->getParamValue('queryExtDbRlsSpec');
  my $subjectTable = $self->getParamValue('subjectTable');
  my $subjectTableIdCol = $self->getParamValue('subjectTableSrcIdCol');
  my $subjectExtDbRlsSpec = $self->getParamValue('subjectExtDbRlsSpec');

  my $queryColArg = "--queryTableSrcIdCol $queryTableSrcIdCol" if $queryTableSrcIdCol;

  my $subjectColArg = "--subjectTableSrcIdCol $subjectTableSrcIdCol" if $subjectTableSrcIdCol;

  my $queryExtDbArg = "";
  if ($queryExtDbRlsSpec) {
      $queryDbName = $self->getDbName($queryExtDbRlsSpec);
      $queryDbRlsVer = $self->getDbName($queryExtDbRlsSpec);
      $queryExtDbArg = " --queryExtDbName '$queryDbName' --queryExtDbRlsVer '$queryDbRlsVer'";
  }

  my $subjectExtDbArg = "";
  if ($subjectExtDbRlsSpec) {
      $subjectDbName = $self->getDbName($subjectExtDbRlsSpec);
      $subjectDbRlsVer = $self->getDbName($subjectExtDbRlsSpec);
      $subjectExtDbArg = " --subjectExtDbName '$subjectDbName' --subjectExtDbRlsVer '$subjectDbRlsVer'";
  }

  my $sbjDbNameArg = " --subjectExtDbName '$subjectDbName'" if $subjectDbName ne '';
  my $sbjRlsArg = " --subjectExtDbRlsVer '$subjectDbRlsVer'" if $subjectDbRlsVer ne '';
  
  my $args = "--file $file $restartAlgInvs --queryTable $queryTable $queryColArg$queryExtDbArg  --subjectTable $subjectTable $subjectColArg $subjectExtDbArg $addedArgs";

  $self->runPlugin("GUS::Supported::Plugin::InsertBlastSimilarities", $args);
}

sub restart {
}

sub undo {

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
	);
}

sub getConfigurationDeclaration {
    return ();
}

sub getDocumentation {
}
