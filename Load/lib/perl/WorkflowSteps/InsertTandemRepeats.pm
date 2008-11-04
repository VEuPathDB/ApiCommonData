package ApiCommonData::Load::WorkflowSteps::LoadTandemRepeats;

@ISA = (GUS::Workflow::WorkflowStepInvoker);

use strict;
use GUS::Workflow::WorkflowStepInvoker;


sub run {
  my ($self, $test) = @_;

  my $tandemRepFile = $self->getParamValue('inputFile');
  
  my $genomeExtDbRlsSpec = $self->getParamValue('genomeExtDbRlsSpec'); 

  my ($extDbName,$extDbRlsVer);

  if ($genomeExtDbRlsSpec =~ /(.+)\|(.+)/) {

      $extDbName = $1;

      $extDbRlsVer = $2

    } else {

      die "Database specifier '$genomeExtDbRlsSpec' is not in 'name|version' format";
  }

  my $args = "--tandemRepeatFile $tandemRepFile --extDbName '$extDbName' --extDbVersion '$extDbRlsVer'";
  
  $self->runPlugin("GUS::Supported::Plugin::InsertTandemRepeatFeatures", $args);
}

sub restart {
}

sub undo {

}

sub getConfigDeclaration {
  my @properties = 
    (
     # [name, default, description]
     ['inputFile', "", ""],
     ['genomeExtDbRlsSpec', "", ""],
    );
  return @properties;
}

sub getDocumentation {
}
1
