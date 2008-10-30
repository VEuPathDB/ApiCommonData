package ApiCommonData::Load::WorkflowSteps::AssembleTranscripts;

@ISA = (GUS::Workflow::WorkflowStepInvoker);

use strict;
use GUS::Workflow::WorkflowStepInvoker;


## to do
## API $self->runCmdInBackground 

sub run {
  my ($self, $test) = @_;

  my $inputFile = $self->getParamValue('inputFile');

  my $outputDir = $self->getParamValue('outputDir');

  my $taxonId = $self->getTaxonId($self->getParamValue('ncbiTaxonId'));

  my $reassemble = $self->getParamValue('reassemble') eq "yes" ? "--reassemble" :"";

  my $cap4Dir = $self->getConfig('cap4Dir');

  my $workingDir = $self->runCmd($test,"pwd");

  &splitClusterFile($test,$inputFile);

  &runAssemblePlugin($test,"big",$inputFile,$outputDir, $reassemble, $taxonId, $cap4Dir); 

  $self->runCmd($test,"sleep 10");

  &runAssemblePlugin($test,"small",$inputFile,$outputDir, $reassemble, $taxonId, $cap4Dir); 

  $self->runCmd($test,"chdir $workingDir") || die "Can't chdir to $workingDir";

}


sub splitClusterFile{

  my ($test,$inputFile) = @_;

  my $cmd = "splitClusterFile $inputFile";

  if ($test){
      self->runCmd(0,'test > $inputFile.small');
      self->runCmd(0,'test > $inputFile.big');
  }else{
      self->runCmd($test,$cmd);      
  }

}

sub runAssemblePlugin{

  my ($test,$suffix, $inputFile,$outputDir, $reassemble, $taxonId, $cap4Dir) = @_;

  my $args = "--clusterfile $inputFile.$suffix $reassemble --taxon_id $taxonId --cap4Dir $cap4Dir";
  
  my $pluginCmd = "ga DoTS::DotsBuild::Plugin::UpdateDotsAssembliesWithCap4 --commit $args --comment '$args'";

  my $cmd = "runUpdateAssembliesPlugin --clusterFile $inputFile.$suffix --pluginCmd \"$pluginCmd\"";

  my $assemDir = "$outputDir/$suffix";

  $self->runCmd(0,"mkdir -p $assemDir") if ! -d $assemDir;
  
  $self->runCmd($test,"chdir $assemDir") || die "Can't chdir to $assemDir";

  $self ->runCmdInBackground($test,$cmd);
}

sub restart {
}

sub undo {

}

sub getConfigDeclaration {
  my @properties = 
    (
     # [name, default, description]
     ['parentNcbiTaxonId', "", ""],
     ['inputFile', "", ""],
     ['cap4Dir', "", ""],
    );
  return @properties;
}

sub getDocumentation {
}
