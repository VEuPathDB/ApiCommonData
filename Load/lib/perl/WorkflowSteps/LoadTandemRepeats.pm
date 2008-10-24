package ApiCommonData::Load::WorkflowSteps::LoadTandemRepeats;

@ISA = (GUS::Workflow::WorkflowStepInvoker);

use strict;
use GUS::Workflow::WorkflowStepInvoker;


sub run {
  my ($self, $test) = @_;

  my $seqFile = $self->getParamValue('seqFile');
  
  my $seqfilesDir = $self->getParamValue('$seqfilesDir');

  my $repeatFinderArgs = $self->getParamValue('$repeatFinderArgs');

  $repeatFinderArgs =~ s/\s+/\./g;

  my $genomeName = $self->getParamValue('genomeName'); 
 
  my $genomeExtDbRlsSpec = $self->getParamValue('genomeExtDbRlsSpec'); 

  my ($extDbName,$extDbRlsVer);

  if ($genomeExtDbRlsSpec =~ /(.+)\:(.+)/) {
      $extDbName = $1;
      $extDbRlsVer = $2
    } else {
      die "Database specifier '$genomeExtDbRlsSpec' is not in 'name:version' format";
  }

  my $dataDir = $self->getGlobalConfig('dataDir');
  
  my $projectName = $self->getGlobalConfig('projectName');
 
  my $projectVersion = $self->getGlobalConfig('projectVersion');

  my $trfDir = "$dataDir/$projectName/$projectVersion/primary/data/$genomeName/trf";

  my $tandemRepFile = "$trfDir/$seqFile.$repeatFinderArgs.dat";

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
     ['seqFile', "", ""],
     ['seqfilesDir', "", ""],
     ['repeatFinderArgs', "", ""],
     ['genomeName',"",""],
     ['trfPath',"",""],
    );
  return @properties;
}

sub getDocumentation {
}
1
