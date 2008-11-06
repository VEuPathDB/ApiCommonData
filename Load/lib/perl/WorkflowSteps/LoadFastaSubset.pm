package ApiCommonData::Load::WorkflowSteps::LoadFastaSubset;

@ISA = (GUS::Workflow::WorkflowStepInvoker);

use strict;
use GUS::Workflow::WorkflowStepInvoker;


sub run {
  my ($self, $test) = @_;

  my $extDbRlsSpec = $self->getParamValue('extDbRlsSpec');

  my ($extDbName, $extDbRlsVer);

  if ($extDbRlsSpec =~ /(.+)\|(.+)/) {

      $extDbName = $1;

      $extDbRlsVer = $2
    } else {

      die "Database specifier '$extDbRlsSpec' is not in 'name|version' format";
  }

  my $fastaFile = $self->getParamValue('fastaFile');

  my $idsFile = $self->getParamValue('idsFile');

  $self->runCmd(0,"gunzip -f $fastaFile") if (-e "${fastaFile}.gz");

  my $args = "--externalDatabaseName $extDbName --externalDatabaseVersion $extDbRlsVer --sequenceFile $fastaFile --sourceIdsFile  $idsFile --regexSourceId  '>gi\\|(\\d+)\\|' --regexDesc '^>(.+)' --tableName DoTS::ExternalAASequence";

  $self->runPlugin("GUS::Supported::Plugin::LoadFastaSequences",$args);

}

sub restart {
}

sub undo {

}

sub getConfigDeclaration {
  my @properties = 
    (
    );
  return @properties;
}

sub getParamDeclaration {
  my @properties = 
    (
     # [name, default, description]
     ['idsFile'],
     ['extDbRlsSpec'],
     ['fastaFile'],
    );
  return @properties;
}


sub getDocumentation {
}
