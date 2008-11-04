package ApiCommonData::Load::WorkflowSteps::InsertAAiP;

@ISA = (GUS::Workflow::WorkflowStepInvoker);

use strict;
use GUS::Workflow::WorkflowStepInvoker;


sub run {
  my ($self, $test) = @_;

  my $extDbRlsSpec = $self->getParamValue('genomeExtDbRlsSpec');

  my ($extDbName, $extDbRlsVer);

  if ($extDbRlsSpec =~ /(.+)\|(.+)/) {

      $extDbName = $1;

      $extDbRlsVer= $2

    } else {

      die "Database specifier '$extDbRlsSpec' is not in 'name|version' format";
  }

  my $table = $self->getParamValue('table');

  my $args = "--extDbRlsName '$extDbName' --extDbRlsVer '$extDbRlsVer' --seqTable $table";

  $self->runPlugin("GUS::Supported::Plugin::CalculateAASequenceIsoelectricPoint",$args);

}

sub restart {
}

sub undo {

}

sub getConfigDeclaration {
  my @properties = 
    (
     # [name, default, description]
     ['genomeExtDbRlsSpec', "", ""],
     ['table', "", ""],
    );
  return @properties;
}

sub getDocumentation {
}
