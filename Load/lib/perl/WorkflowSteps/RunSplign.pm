package ApiCommonData::Load::WorkflowSteps::RunSplign;

@ISA = (GUS::Workflow::WorkflowStepInvoker);

use strict;
use GUS::Workflow::WorkflowStepInvoker;


sub run {
  my ($self, $test) = @_;

  my $queryFile = $self->getParamValue('queryFile');
  
  my $subjectFile = $self->getParamValue('subjectFile');

  my $outputFile = $self->getParamValue('outputFile');
 
  my $splignDir = $self->getParamValue('outputDir');

  my $splignPath = $self->getConfig('splignPath');

  my $ncbiBlastPath = $self->getConfig('ncbiBlastPath');

  if ($test) {

      $self->runCmd(0,"test > $outputFile");

  } else {

      $self->runCmd("${splignPath}/splign -mklds $splignDir");

      $self->runCmd("${ncbiBlastPath}/formatdb -i $subjectFile -p F -o F");

      $self->runCmd("${ncbiBlastPath}/megablast -i $queryFile -d $subjectFile -m 8 | sort -k 2,2 -k 1,1 > $splignDir/test.hit");

      $self->runCmd("${splignPath}/splign -ldsdir $splignDir -hits $splignDir/test.hit > $outputFile");

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
     ['queryFile', "", ""],
     ['subjectFile', "", ""],
     ['outputFile', "", ""],
     ['splignDir', "", ""],
     ['splignPath', "", ""],
     ['ncbiBlastPath', "", ""],
    );
  return @properties;
}

sub getDocumentation {
}
