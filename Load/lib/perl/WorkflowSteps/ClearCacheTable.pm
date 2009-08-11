package ApiCommonData::Load::WorkflowSteps::ClearCacheTable;

@ISA = (ApiCommonData::Load::WorkflowSteps::WorkflowStep);

use strict;
use ApiCommonData::Load::WorkflowSteps::WorkflowStep;


sub run {
  my ($self, $test, $undo) = @_;

  my $cacheTable = $self->getParamValue('cacheTable');
  my $organismFullName = $self->getParamValue('organismFullName');
  my $deprecated = ($self->getParamValue('deprecated') eq 'true') ? 1 :0;
  my $attributesTable = $self->getParamValue('attributesTable');

  my $sql = "delete from $cacheTable where source_id in (select distinct source_id from $attributesTable where organism='$organismFullName' and is_deprecated=$deprecated)";

  $sql = "delete from $cacheTable where source_id in (select distinct source_id from $attributesTable where is_deprecated=$deprecated)" if ($organismFullName eq '');


  my $cmd = "executeIdSQL.pl --idSQL \"$sql\"";


  if ($undo){
     $self->runCmd(0, "echo Doing nothing for \"undo\" Clear Cache Table.\n");  
  }else{
      if ($test) {
      }else {
	  $self->runCmd($test, $cmd);
      }
  }


}

sub getParamsDeclaration {
  return (
	  'cacheTable',
	  'organismFullName',
	  'deprecated',
	  'attributesTable',
	 );
}

sub getConfigDeclaration {
  return (
	  # [name, default, description]
	 );
}


