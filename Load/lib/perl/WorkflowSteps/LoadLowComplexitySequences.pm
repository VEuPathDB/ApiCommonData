package ApiCommonData::Load::WorkflowSteps::LoadLowComplexitySequences;

@ISA = (GUS::Workflow::WorkflowStepInvoker);

use strict;
use GUS::Workflow::WorkflowStepInvoker;


sub run {
  my ($self, $test) = @_;

  my $seqfilesDir = $self->getParamValue('seqfilesDir');

  my $inputFile = $self->getParamValue('inputFile');

  my $genomeExtDbRlsSpec = $self->getParamValue('genomeExtDbRlsSpec'); 

  my ($extDbName,$extDbRlsVer);

  if ($genomeExtDbRlsSpec =~ /(.+)\:(.+)/) {
      $extDbName = $1;
      $extDbRlsVer = $2
    } else {
      die "Database specifier '$genomeExtDbRlsSpec' is not in 'name:version' format";
  }
  
  my $genomeName = $self->getParamValue('genomeName'); 
 
  my $seqType = $self->getParamValue('seqType'); 

  my $mask = $self->getParamValue('mask');

  my $opt = $self->getParamValue('opt');

  my $dataDir = $self->getGlobalConfig('dataDir');
  
  my $projectName = $self->getGlobalConfig('projectName');
 
  my $projectVersion = $self->getGlobalConfig('projectVersion');

  my $input = "$dataDir/$projectName/$projectVersion/primary/data/$genomeName/$seqfilesDir/ $inputFile";

  my $args = "--seqFile $input --fileFormat 'fasta' --extDbName '$extDbName' --extDbVersion '$extDbRlsVer' --seqType $seqType --maskChar $mask $opt";
   
  $self->runPlugin("ApiCommonData::Load::Plugin::InsertLowComplexityFeature", $args);
}

sub restart {
}

sub undo {

}

sub getConfigDeclaration {
  my @properties = 
    (
     # [name, default, description]
     ['seqfilesDir', "", ""],
     ['inputFile', "", ""],
     ['genomeExtDbRlsSpec', "", ""],
     ['genomeName',"",""],
     ['seqType',"",""],
    );
  return @properties;
}

sub getDocumentation {
}
1
