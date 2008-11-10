package ApiCommonData::Load::WorkflowSteps::InsertSignalP;

@ISA = (ApiCommonData::Load::WorkflowSteps::WorkflowStep);

use strict;
use ApiCommonData::Load::WorkflowSteps::WorkflowStep;


sub run {
  my ($self, $test) = @_;

  my $inputFile = $self->getParamValue('inputFile');

  my $genomeExtDbRlsSpec = $self->getParamValue('genomeExtDbRlsSpec'); 

  my ($extDbName,$extDbRlsVer);

  if ($genomeExtDbRlsSpec =~ /(.+)\|(.+)/) {

      $extDbName = $1;

      $extDbRlsVer = $2

    } else {

      die "Database specifier '$genomeExtDbRlsSpec' is not in 'name|version' format";
  }

  my $version = $self->getConfig('version');

  my $projectName = $self->getGlobalConfig('projectName');

  my $desc = "SignalP version $version";

  my $args = "--data_file $inputFile --algName 'SignalP' --algVer '$version' --algDesc '$desc' --extDbName '$extDbName' --extDbRlsVer '$extDbRlsVer' --project_name $projectName --useSourceId";

  $self->runPlugin("ApiCommonData::Load::Plugin::LoadSignalP",$args);

}

sub restart {
}

sub undo {

}

sub getConfigDeclaration {
  my @properties = 
    (
     # [name, default, description]
     ['proteinsFile', "", ""],
     ['outputFile', "", ""],
     ['options', "", ""],
    );
  return @properties;
}

sub getParamDeclaration {
  my $properties =
     ['proteinsFile'],
     ['outputFile'],
     ['options'],
  return $properties;
}

sub getDocumentation {
}
