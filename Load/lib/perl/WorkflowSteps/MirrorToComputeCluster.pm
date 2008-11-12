package ApiCommonData::Load::Steps::WorkflowSteps::LoadFastaSequence;

@ISA = (GUS::Pipeline::WorkflowStep);

use ApiCommonData::Load::MakeTaskDirs;

## copy a file from a directory in our local home dir to the cluster home dir.
## the directory structures in both locations are assumed to be the same, so the 

sub run {
  my ($self) = @_;

  # get param values
  my $file = $self->getParam('file');  
  my $relativeDir = $self->getParam('relativeDir');  # dir name relative to home dir

  # get global config values
  my $clusterServer = $self->getGlobalConfig('clusterServer');
  my $clusterProjectDir = $self->getGlobalConfig('clusterProjectDir');
  my $dataDir = $self->getGlobalConfig('dataDir');

  # FIX THIS
  $self->copyToCluster("$dataDir/$relativeDir",
		       $file,
		       "$clusterProjectDir/$dataDir/$relativeDir");
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
