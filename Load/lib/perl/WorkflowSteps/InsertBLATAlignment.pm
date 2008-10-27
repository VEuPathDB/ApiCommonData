package ApiCommonData::Load::WorkflowSteps::InsertBLATAlignment;

@ISA = (GUS::Workflow::WorkflowStepInvoker);

use strict;
use GUS::Workflow::WorkflowStepInvoker;

## to do
## $targetExtDbRlsId = $self->getDbRlsId($self->getParamValue('targetExtDbRlsSpec'))
## $queryTableId = $self->getTableId($self->getParamValue('queryTable'))

sub run {
  my ($self, $test) = @_;

  my $targetTaxonId = $self->getTaxonId($self->getParamValue('targetNcbiTaxId'));

  my $queryTaxonId = $self->getTaxonId($self->getParamValue('queryNcbiTaxId'));

  my $BLATQueryName = $self->getParamValue('BLATQueryName');

  my $BLATTargetName = $self->getParamValue('BLATTargetName');

  my $targetExtDbRlsId = $self->getDbRlsId($self->getParamValue('targetExtDbRlsSpec'));

  my $queryExtDbRlsId = $self->getDbRlsId($self->getParamValue('queryExtDbRlsSpec'));

  my $targetTableId = $self->getTableId($self->getParamValue('targetTable'));

  my $queryTableId = $self->getTableId($self->getParamValue('queryTable'));

  my $regex = $self->getParamValue('regex');

  my $action = $self->getParamValue('action');

  my $percentTop = $self->getParamValue('percentTop');
  
  my $BLATFile = $self->getParamValue('BLATFile');
  
  my $queryFile = $self->getParamValue('queryFile');

  # copy qFile to /tmp directory to work around a bug in the
  # LoadBLATAlignments plugin's call to FastaIndex
  
  my $queryDir = "/tmp/" . $BLATQueryName;
  
  my $tmpFile = $queryDir . "/blocked.seq";

  $self->runCmd(0,"mkdir -p $queryDir")if ! -d $qDir;
  
  $self->runCmd(0,"cp $queryFile $tmpFile")if ! -e $tmpFile;

  my $args = "--blat_files '$BLATFile' --query_file $tmpFile --action '$action' --queryRegex '$regex'"
    . " --query_table_id $queryTableId --query_taxon_id $queryTaxonId"
  . " --target_table_id  $targetTableId --target_db_rel_id $targetExtDbRlsId --target_taxon_id $targetTaxonId"
    . " --max_query_gap 5 --min_pct_id 95 --max_end_mismatch 10"
      . " --end_gap_factor 10 --min_gap_pct 90 "
        . " --ok_internal_gap 15 --ok_end_gap 50 --min_query_pct 10";

  $args .= " --query_db_rel_id $queryExtDbRlsId" if $queryExtDbRlsId;

  $args .= " --percentTop $percentTop" if $percentTop;

  $self->runPlugin( "GUS::Community::Plugin::LoadBLATAlignments", $args);
 
  $self->runCmd(0,"rm -rf $queryDir") if -d $queryDir;
}


sub restart {
}

sub undo {

}

sub getConfigDeclaration {
  my @properties = 
    (
     # [name, default, description]
     ['targetTaxonId', "", ""],
     ['queryTaxonId', "", ""],
    );
  return @properties;
}

sub getDocumentation {
}
