package ApiCommonData::Load::WorkflowSteps::RunTuningManager;

@ISA = (ApiCommonData::Load::WorkflowSteps::WorkflowStep);

use strict;
use ApiCommonData::Load::WorkflowSteps::WorkflowStep;


sub run {
  my ($self, $test, $undo) = @_;

  my $configFile = $self->getParamValue('configFileRelativeToGusHomeDir');

  my $gusHome = $self->getGlobalConfig('gusHome');
  my $email = $self->getGlobalConfig('email');
  my $instance = $self->getGlobalConfig('instance');

  my $apidbPassword = $self->getConfig('apidbPassword');
  my $xmlConfigFileName="tmpConfigFile.xml";
  my $xmlConfigFileString=
"<?xml version='1.0'?>
<property>
<password>$apidbPassword</password>
<username>apidb</username>
</property>
";
  open(F,">$xmlConfigFileName");
  print F $xmlConfigFileString;
  close F;
  my $cmd;

      $cmd = "tuningManager -configFile $gusHome/$configFile  --instance '$instance' --propFile $xmlConfigFileName --doUpdate --notifyEmail '$email' --cleanupAge 0";


  if ($undo){
     $self->runCmd(0, "echo Doing nothing for \"undo\" Tuning Manager.\n");  
  }else{
      if ($test) {
	  $self->testInputFile('configFile', "$gusHome/$configFile");
      }else {
	  $self->runCmd($test, $cmd);
      }
  }


}

sub getParamsDeclaration {
  return (
	  'configFile',
	 );
}

sub getConfigDeclaration {
  return (
	  # [name, default, description]
	 );
}


