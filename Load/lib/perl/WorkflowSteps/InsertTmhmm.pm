package ApiCommonData::Load::WorkflowSteps::InsertTmhmm;

@ISA = (ApiCommonData::Load::WorkflowSteps::WorkflowStep);

use strict;
use ApiCommonData::Load::WorkflowSteps::WorkflowStep;


sub run {
  my ($self, $test) = @_;

  my $inputFile = $self->getParamValue('inputFile');

  my $version = $self->getConfig('version');

  my $desc = "TMHTMM version $version";

  my $genomeExtDbRlsSpec = $self->getParamValue('genomeExtDbRlsSpec'); 

  my ($extDbName,$extDbRlsVer);

  if ($genomeExtDbRlsSpec =~ /(.+)\|(.+)/) {

      $extDbName = $1;

      $extDbRlsVer = $2

    } else {

      die "Database specifier '$genomeExtDbRlsSpec' is not in 'name|version' format";
  }

  my $args = "--data_file $inputFile --algName TMHMM --algDesc '$desc' --useSourceId --extDbName '$extDbName' --extDbRlsVer '$extDbRlsVer'";

  $self->runPlugin("ApiCommonData::Load::Plugin::LoadTMDomains",$args);

}

sub restart {
}

sub undo {

}

sub getConfigDeclaration {
  my @properties = 
    (
     # [name, default, description]
     ['version', "", ""],
    );
  return @properties;
}

sub getParamDeclaration {
  my @properties = 
    (
     ['inputFile'],
     ['genomeExtDbRlsSpec'],
    );
  return @properties;
}

sub getDocumentation {
}
