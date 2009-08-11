package ApiCommonData::Load::WorkflowSteps::CreateFullRecordCache;

@ISA = (ApiCommonData::Load::WorkflowSteps::WorkflowStep);

use strict;
use ApiCommonData::Load::WorkflowSteps::WorkflowStep;


sub run {
  my ($self, $test, $undo) = @_;

  my $record = $self->getParamValue('record');
  my $organismFullName = $self->getParamValue('organismFullName');
  my $attributesTable = $self->getParamValue('attributesTable');
  my $cacheTable = $self->getParamValue('cacheTable');
  my $model = $self->getParamValue('model');
  my $deprecated = ($self->getParamValue('deprecated') eq 'true') ? 1 :0;

  my $sqlFile="all_PKs.sql";

  my $sqlFileString="SELECT DISTINCT project_id, source_id FROM $attributesTable where organism ='$organismFullName' and is_deprecated=$deprecated";

  $sqlFileString="SELECT DISTINCT project_id, source_id FROM $attributesTable where is_deprecated=$deprecated" if ($organismFullName eq '');
  open(F,">$sqlFile");
  print F $sqlFileString;
  close F;
  my $cmd = "createFullRecordCache -record $record -sqlFile $sqlFile -cacheTable $cacheTable -model $model  >> FullRecordCacheDumpDetails.out 2>> FullRecordCacheDumpDetails.err &";



  if ($undo){

      my $sql = "delete from $cacheTable where source_id in (select distinct source_id from $attributesTable where organism='$organismFullName' and is_deprecated=$deprecated)";

      $sql = "delete from $cacheTable where source_id in (select distinct source_id from $attributesTable where organism='$organismFullName' and is_deprecated=$deprecated)" if ($organismFullName eq '');

      my $undoCmd = "executeIdSQL.pl  --idSQL \"$sql\"";
     
      $self->runCmd(0, $undoCmd); 
 
  }else{
      if ($test) {
      }else {
	  $self->runCmd($test, $cmd);
      }
  }

}

sub getParamsDeclaration {
  return (
	  'record',
	  'organismFullName',
	  'attributesTable',
	  'cacheTable',
	  'model',
	  'deprecated',
	 );
}

sub getConfigDeclaration {
  return (
	  # [name, default, description]
	 );
}


