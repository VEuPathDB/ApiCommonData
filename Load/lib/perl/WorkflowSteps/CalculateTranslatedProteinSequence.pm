package ApiCommonData::Load::WorkflowSteps::CalculateTranslatedProteinSequence;

@ISA = (GUS::Workflow::WorkflowStepInvoker);

use strict;
use GUS::Workflow::WorkflowStepInvoker;


sub run {
  my ($self, $test) = @_;

  my $extDbRlsSpec = $self->getParamValue('genomeExtDbRlsSpec');

  my ($extDbName, $extDbRlsVer);

  if ($extDbRlsSpec =~ /(.+)\|(.+)/) {

      $extDbName = $1;

      $extDbRlsVer = $2

    } else {

      die "Database specifier '$extDbRlsSpec' is not in 'name|version' format";
  }

  my $soVersion = $self->getParamValue('soVersion');

  my $args = "--sqlVerbose --extDbRlsName '$extDbName' --extDbRlsVer '$extDbRlsVer' --soCvsVersion $soVersion";

  $self->runPlugin("GUS::Supported::Plugin::CalculateTranslatedAASequences",$args);

}

sub restart {
}

sub undo {

}

sub getConfigDeclaration {
  my @properties = 
    (
     # [name, default, description]
    );
  return @properties;
}

sub getConfigDeclaration {
  my @properties = 
    (
     ['genomeExtDbRlsSpec'],
     ['soVersion'],
    );
  return @properties;
}

sub getDocumentation {
}
