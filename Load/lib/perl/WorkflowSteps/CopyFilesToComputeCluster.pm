package ApiCommonData::Load::Steps::WorkflowSteps::LoadFastaSequence;

@ISA = (GUS::Pipeline::WorkflowStep);

use ApiCommonData::Load::MakeTaskDirs;

sub run {
  my ($self) = @_;

  my $file = $self->getConfig('file');
  
  my $dir = $self->getConfig('dir');

  my $clusterServer = $propertySet->getProp('clusterServer');
  
  my $dataDir = $self->getConfig('dataDir');

  my $fileDir = "$dataDir/$dir";

  $mgr->{cluster}->copyTo($fileDir, $file, "$mgr->{clusterDataDir}/$dir");

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
