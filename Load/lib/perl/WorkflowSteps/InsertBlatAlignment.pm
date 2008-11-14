package ApiCommonData::Load::WorkflowSteps::InsertBLatlignment;

@ISA = (ApiCommonData::Load::WorkflowSteps::WorkflowStep);

use strict;
use ApiCommonData::Load::WorkflowSteps::WorkflowStep;

sub run {
  my ($self, $test) = @_;

  my $targetTaxonId = $self->getTaxonId($self->getParamValue('targetNcbiTaxId'));
  my $targetExtDbRlsSpec = $self->getParamValue('targetExtDbRlsSpec');
  my $targetTableId = $self->getTableId($self->getParamValue('targetTable'));

  my $queryTaxonId = $self->getTaxonId($self->getParamValue('queryNcbiTaxId'));
  my $queryExtDbRlsSpec = $self->getParamValue('queryExtDbRlsSpec');
  my $queryTable = $self->getParamValue('queryTable');
  my $queryFile = $self->getParamValue('queryFile');

  my $regex = $self->getParamValue('regex');
  my $action = $self->getParamValue('action');
  my $percentTop = $self->getParamValue('percentTop');
  my $blatFile = $self->getParamValue('blatFile');

  my $targetExtDbRlsId = $self->getExtDbRlsId($targetExtDbRlsSpec);
  my $queryExtDbRlsId = $self->getExtDbRlsId($queryExtDbRlsSpec) if $queryExtDbRlsSpec;
  my $queryTableId = $self->getTableId($queryTable);

  my $localDataDir = $self->getLocalDataDir();

  my $args = "--blat_files '$localDataDir/$blatFile' --query_file $localDataDir/$queryFile --action '$action' --queryRegex '$regex' --query_table_id $queryTableId --query_taxon_id $queryTaxonId --target_table_id  $targetTableId --target_db_rel_id $targetExtDbRlsId --target_taxon_id $targetTaxonId --max_query_gap 5 --min_pct_id 95 --max_end_mismatch 10 --end_gap_factor 10 --min_gap_pct 90  --ok_internal_gap 15 --ok_end_gap 50 --min_query_pct 10";

  $args .= " --query_db_rel_id $queryExtDbRlsId" if $queryExtDbRlsId;

  $args .= " --percentTop $percentTop" if $percentTop;

  $self->runPlugin($test, "GUS::Community::Plugin::LoadBLATAlignments", $args);
}

sub getParamDeclaration {
  return (
	  'targetTaxonId',
	  'queryTaxonId',
	  'targetExtDbRlsSpec',
	  'queryExtDbRlsSpec',
	  'regex',
	  'action',
	  'percentTop',
	  'blatFile',
	  'queryFile',
	  'targetTable',
	  'queryTable',
	 );
}

sub getConfigDeclaration {
  return (
	  # [name, default, description]
	 );
}

sub getDocumentation {
}

sub restart {
}

sub undo {

}
