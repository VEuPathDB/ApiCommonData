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

      $mgr->runCmd("${splignPath}/splign -mklds $splignDir");

      $mgr->runCmd("${ncbiBlastPath}/formatdb -i $subjectFile -p F -o F");

      $mgr->runCmd("${ncbiBlastPath}/megablast -i $queryFile -d $subjectFile -m 8 | sort -k 2,2 -k 1,1 > $splignDir/test.hit");

      $mgr->runCmd("${splignPath}/splign -ldsdir $splignDir -hits $splignDir/test.hit > $outputFile");

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
     ['genomeName', "", ""],
     ['seqType', "", ""],
     ['table', "", ""],
     ['identifier', "", ""],
     ['ncbiTaxId', "", ""],
     ['genomeExtDbRlsSpec', "", ""],
     ['outputFile', "", ""],
    );
  return @properties;
}

sub getDocumentation {
}
