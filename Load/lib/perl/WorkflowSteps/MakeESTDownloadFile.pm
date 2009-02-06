package ApiCommonData::Load::WorkflowSteps::MakeESTDownloadFile;

@ISA = (ApiCommonData::Load::WorkflowSteps::WorkflowStep);
use strict;
use ApiCommonData::Load::WorkflowSteps::WorkflowStep;

sub run {
  my ($self, $test, $undo) = @_;

  # get parameters
  my $outputFile = $self->getParamValue('outputFile');
  my $parentNcbiTaxonId = $self->getParamValue('parentNcbiTaxonId');
  my $useTaxonHierarchy = $self->getParamValue('useTaxonHierarchy');

  my $apiSiteFilesDir = $self->getGlobalConfig('apiSiteFilesDir');

  my $taxonId = $self->getTaxonIdFromNcbiTaxId($test,$parentNcbiTaxonId);
  my $taxonIdList = $self->getTaxonIdList($test, $taxonId, $useTaxonHierarchy);

  my $sql = <<"EOF";
    SELECT x.source_id
           ||' | organism='||
           replace(tn.name, ' ', '_')
           ||' | length='||
           x.length as defline,
           x.sequence
           FROM dots.externalnasequence x,
                sres.taxonname tn,
                sres.taxon t,
                sres.sequenceontology so
           WHERE t.taxon_id in ($taxonIdList)
            AND t.taxon_id = tn.taxon_id
            AND tn.name_class = 'scientific name'
            AND t.taxon_id = x.taxon_id
            AND x.sequence_ontology_id = so.sequence_ontology_id
            AND so.term_name = 'EST'
EOF

  my $cmd = " gusExtractSequences --outputFile $apiSiteFilesDir/$outputFile  --idSQL \"$sql\"";

  if ($test) {
      $self->runCmd(0, "echo test > $apiSiteFilesDir/$outputFile");
  }elsif($undo){
    $self->runCmd(0, "rm -f $apiSiteFilesDir/$outputFile");
  }
  else{
    $self->runCmd($test, $cmd);
  }
}

sub getParamsDeclaration {
  return (
          'outputFile',
          'parentNcbiTaxonId',
          'useTaxonHierarchy',
         );
}

sub getConfigDeclaration {
  return (
         # [name, default, description]
         # ['', '', ''],
         );
}

