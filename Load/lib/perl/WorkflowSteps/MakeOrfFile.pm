package ApiCommonData::Load::WorkflowSteps::MakeOrfFile;

@ISA = (GUS::Workflow::WorkflowStepInvoker);

use strict;
use GUS::Workflow::WorkflowStepInvoker;


sub run {
  my ($self, $test) = @_;

  my $seqFile = $self->getParamValue('seqFile');
  
  my $minPepLength = $self->getParamValue('minPepLength');

  my $seqfilesDir = $self->getParamValue('seqfilesDir');
  
  my $outFile = $self->getParamValue('outputFile');

  my $genomeName = $self->getParamValue('genomeName');

  my $dataDir = $self->getGlobalConfig('dataDir');

  my $projectName = $self->getGlobalConfig('projectName');
 
  my $projectVersion = $self->getGlobalConfig('projectVersion');

  $seqfilesDir = "$dataDir/$projectName/$projectVersion/primary/data/$genomeName/$seqfilesDir";
  
  $outFile = "$seqfilesDir/$outFile";
 
   my $cmd = <<"EOF";
orfFinder --dataset  $seqfilesDir/$seqFile \\
--minPepLength $minPepLength \\
--outFile $outFile
EOF

  if ($test) {
      $self->runCmd(0,"test > $outFile");
  } else {
      $self->runCmd($test,$cmd);
  }

}


sub restart {
}

sub undo {

}

sub getConfigDeclaration {
  my @properties = 
    (
     # [name, default, description]
     ['seqFile', "", ""],
     ['minPepLength', "", ""],
     ['seqfilesDir', "", ""],
     ['outputFile', "", ""],
    );
  return @properties;
}

sub getDocumentation {
}
