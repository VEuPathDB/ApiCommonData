package ApiCommonData::Load::WorkflowSteps::InsertBLatlignment;

@ISA = (ApiCommonData::Load::WorkflowSteps::WorkflowStep);

use strict;
use ApiCommonData::Load::WorkflowSteps::WorkflowStep;

## to do
## $targetExtDbRlsId = $self->getDbRlsId($self->getParamValue('targetExtDbRlsSpec'))
## $queryTableId = $self->getTableId($self->getParamValue('queryTable'))

sub run {
  my ($self, $test) = @_;

  my $targetTaxonId = $self->getTaxonId($self->getParamValue('targetNcbiTaxId'));

  my $queryTaxonId = $self->getTaxonId($self->getParamValue('queryNcbiTaxId'));

  my $targetExtDbRlsId = $self->getDbRlsId($self->getParamValue('targetExtDbRlsSpec'));

  my $queryExtDbRlsSpec = $self->getParamValue('queryExtDbRlsSpec');

  my $queryExtDbRlsId = $self->getDbRlsId($queryExtDbRlsSpec) if $queryExtDbRlsSpec;

  my $regex = $self->getParamValue('regex');

  my $action = $self->getParamValue('action');

  my $percentTop = $self->getParamValue('percentTop');
  
  my $BlatFile = $self->getParamValue('blatFile');
  
  my $queryFile = $self->getParamValue('queryFile');

  my $targetTableId = $self->getTableId($self->getParamValue('targetTable'));

  my $queryTableId = $self->getTableId($self->getParamValue('queryTable'));

  my $args = "--blat_files '$BlatFile' --query_file $queryFile --action '$action' --queryRegex '$regex'"
    . " --query_table_id $queryTableId --query_taxon_id $queryTaxonId"
  . " --target_table_id  $targetTableId --target_db_rel_id $targetExtDbRlsId --target_taxon_id $targetTaxonId"
    . " --max_query_gap 5 --min_pct_id 95 --max_end_mismatch 10"
      . " --end_gap_factor 10 --min_gap_pct 90 "
        . " --ok_internal_gap 15 --ok_end_gap 50 --min_query_pct 10";

  $args .= " --query_db_rel_id $queryExtDbRlsId" if $queryExtDbRlsId;

  $args .= " --percentTop $percentTop" if $percentTop;

  $self->runPlugin( "GUS::Community::Plugin::LoadBLATAlignments", $args);
 
}


sub restart {
}

sub undo {

}

sub getConfigDeclaration {
  my @properties = 
    (
     # [name, default, description]
    );
  return @properties;
}

sub getParamDeclaration {
  my @properties = 
    (
     # [name, default, description]
     ['targetTaxonId'],
     ['queryTaxonId'],
     ['targetExtDbRlsSpec'],
     ['queryExtDbRlsSpec'],
     ['regex'],
     ['action'],
     ['percentTop'],
     ['blatFile'],
     ['queryFile'],
     ['targetTable'],
     ['queryTable'],
    );
  return @properties;
}

sub getDocumentation {
}
