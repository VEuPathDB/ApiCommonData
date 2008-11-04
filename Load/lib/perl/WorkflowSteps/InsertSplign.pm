package ApiCommonData::Load::WorkflowSteps::InsertSplign;

@ISA = (GUS::Workflow::WorkflowStepInvoker);

use strict;
use GUS::Workflow::WorkflowStepInvoker;


sub run {
  my ($self, $test) = @_;

  my $queryExtDbRlsSpec = $self->getParamValue('queryExtDbRlsSpecc');

  my $subjectExtDbRlsSpec = $self->getParamValue('subjectExtDbRlsSpec');

  my $inputFile = $self->getParamValue('inputFile');
  
  my $queryTable = $self->getParamValue('queryTable');

  my $subjectTable = $self->getParamValue('subjectTable');

  my $args = "--inputFile $inputFile --estTable '$queryTable' --seqTable '$subjectTable' --estExtDbRlsSpec '$queryExtDbRlsSpec' --seqExtDbRlsSpec '$subjectExtDbRlsSpec'";
 
  $self -> runPlugin ("ApiCommonData::Load::Plugin::InsertSplignAlignments", $args);
}



sub restart {
}

sub undo {

}

sub getConfigDeclaration {
  my @properties = 
    (
     # [name, default, description]
     ['queryExtDbRlsSpecc', "", ""],
     ['subjectExtDbRlsSpec', "", ""],
     ['inputFile', "", ""],
     ['queryTable', "", ""],
     ['subjectTable', "", ""],
    );
  return @properties;
}

sub getDocumentation {
}
