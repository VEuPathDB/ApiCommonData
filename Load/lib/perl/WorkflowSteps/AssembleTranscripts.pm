package ApiCommonData::Load::WorkflowSteps::AssembleTranscripts;

@ISA = (GUS::Workflow::WorkflowStepInvoker);

use strict;
use GUS::Workflow::WorkflowStepInvoker;


## to do
## API $self->runCmdInBackground 

sub run {
  my ($self, $test) = @_;

  my $inputFileDir = $self->getParamValue('inputFileOrDir');

  my $taxonId = $self->getTaxonId($self->getParamValue('ncbiTaxonId'));

  my $reassemble = $self->getParamValue('reassemble') eq "yes" ? "--reassemble" :"";

  my $cap4Dir = $self->getConfig('cap4Dir');

  my $workingDir = $self->runCmd($test,"pwd");

  &runAssemblePlugin("big",$inputFileDir, $reassemble, $taxonId, $cap4Dir); 

  $self->runCmd($test,"sleep 10");

  &runAssemblePlugin("small",$inputFileDir, $reassemble, $taxonId, $cap4Dir); 

  $self->runCmd($test,"chdir $workingDir") || die "Can't chdir to $workingDir";

}

sub runAssemblePlugin{

  my ($suffix, $inputFileDir, $reassemble, $taxonId, $cap4Dir) = @_;

  my $args = "--clusterfile $inputFileDir/cluster.out.$suffix $reassemble --taxon_id $taxonId --cap4Dir $cap4Dir";
  
  my $pluginCmd = "ga DoTS::DotsBuild::Plugin::UpdateDotsAssembliesWithCap4 --commit $args --comment '$args'";

  my $cmd = "runUpdateAssembliesPlugin --clusterFile $inputFileDir/cluster.out.$suffix --pluginCmd \"$pluginCmd\"";

  my $assemDir = "$inputFileDir/$suffix";

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
     ['inputFileDir', "", ""],
     ['cap4Dir', "", ""],
    );
  return @properties;
}

sub getDocumentation {
}
