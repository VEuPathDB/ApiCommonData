package ApiCommonData::Load::WorkflowSteps::MakeAndLoadAssemblies;

@ISA = (ApiCommonData::Load::WorkflowSteps::WorkflowStep);

use strict;
use ApiCommonData::Load::WorkflowSteps::WorkflowStep;


## to do
## API $self->runCmdInBackground 

sub run {
  my ($self, $test, $undo) = @_;

  my $inputFile = $self->getParamValue('inputFile');
  my $ncbiTaxonId = $self->getParamValue('ncbiTaxonId');
  my $reassemble = $self->getParamValue('reassemble') eq "yes" ? "--reassemble" :"";

  my $cap4Dir = $self->getConfig('cap4Dir');

  my $taxonId = $self->getTaxonIdFromNcbiTaxId($test,$ncbiTaxonId);

  my $localDataDir = $self->getLocalDataDir();

  my $args = "--clusterfile $localDataDir/$inputFile $reassemble --taxon_id $taxonId --cap4Dir $cap4Dir";

  my $workflowStepId = $self->getId();
  
  my $pluginCmd = "ga DoTS::DotsBuild::Plugin::UpdateDotsAssembliesWithCap4 --commit $args --workflowstepid $workflowStepId --comment '$args'";

  my $cmd = "runUpdateAssembliesPlugin --clusterFile $localDataDir/$inputFile --pluginCmd \"$pluginCmd\"";

  if ($test) {
    $self->testInputFile('inputFile', "$localDataDir/$inputFile");
  }

  if ($undo) {
    $self->runPlugin($test, $undo, $pluginCmd);
  }else {
    $self->runCmd($test, $cmd);
  }
}


sub getConfigDeclaration {
  my @properties = 
    (
     # [name, default, description]
     ['cap4Dir', "", ""],
    );
  return @properties;
}

sub getParamDeclaration {
  my @properties = 
    (
     ['inputFile',
      'ncbiTaxonId',
      'reassemble',
     ]
    );
  return @properties;
}


