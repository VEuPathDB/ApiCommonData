package ApiCommonData::Load::Steps::WorkflowSteps::LoadFastaSequence;

@ISA = (GUS::Pipeline::WorkflowStep);

use ApiCommonData::Load::MakeTaskDirs;

sub run {
  my ($self) = @_;

  my $dataDir = $self->getConfig('dataDir');

  my $clusterDataDir = $mgr->{clusterDataDir};

  my $nodePath = $propertySet->getProp('nodePath');

  my $nodeClass = $propertySet->getProp('nodeClass');

  my $bsTaskSize = $propertySet->getProp('blastsimilarity.taskSize');

  my $blastBinPathCluster = $propertySet->getProp('wuBlastBinPathCluster');

  my $blastBinPathCluster = $propertySet->getProp('ncbiBlastBinPathCluster') if ($vendor eq 'ncbi');

  my $queryFile = $self->getConfig('queryFile');

  my $subjectFile = $self->getConfig('subjectFile');

  my $blastType = $self->getConfig('blastType');

  my $dbType = ($blastType =~ m/blastn|tblastx/i) ? 'n' : 'p';

  my $bsParams = $self->getConfig('blastArgs');

  my $regex = $self->getConfig('idRegex');

  $self->makeSimilarityDir($queryFile, $subjectFile, $dataDir, $clusterDataDir,
		           $nodePath, $bsTaskSize,
			   $blastBinPathCluster,
			   "${subjectFile}.fsa", "$clusterDataDir/seqfiles", "${queryFile}.fsa", $regex, $blastType, $bsParams, $nodeClass,$dbType,$vendor);
}

sub restart {
}

sub undo {

}

sub getConfigDeclaration {
  my @properties = 
    (
     # [name, default, description]
     ['', "", ""],
     ['', "", ""],
     ['', "", ""],
     ['', "", ""],
     ['', "", ""],
     ['', "", ""],
     ['', "", ""],
     ['' "", ""],
    );
  return @properties;
}

sub getDocumentation {
}
