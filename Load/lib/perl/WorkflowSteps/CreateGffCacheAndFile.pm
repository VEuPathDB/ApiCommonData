package ApiCommonData::Load::WorkflowSteps::CreateGffCacheAndFile;

@ISA = (ApiCommonData::Load::WorkflowSteps::WorkflowStep);

use strict;
use ApiCommonData::Load::WorkflowSteps::WorkflowStep;


sub run {
  my ($self, $test, $undo) = @_;

  my $organismFullName = $self->getParamValue('organismFullName');
  my $model = $self->getParamValue('model');
  my $deprecated = ($self->getParamValue('deprecated') eq 'true') ? 1 :0;

  my $cmd = "gffDump -model $model -organism '$organismFullName'  >> GffCacheAndFileDetails.out 2>> GffCacheAndFileDetails.err &";


  if ($undo){

      my $sql = "delete from ApiDB.GENETABLE where source_id in (select distinct source_id from ApiDB.GENEATTRIBUTES where organism='$organismFullName' and is_deprecated=$deprecated)";

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


