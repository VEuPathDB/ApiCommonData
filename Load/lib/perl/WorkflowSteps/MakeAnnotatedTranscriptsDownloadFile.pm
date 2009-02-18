package ApiCommonData::Load::WorkflowSteps::MakeAnnotatedTranscriptsDownloadFile;

@ISA = (ApiCommonData::Load::WorkflowSteps::WorkflowStep);
use strict;
use ApiCommonData::Load::WorkflowSteps::WorkflowStep;


sub run {
  my ($self, $test, $undo) = @_;

  # get parameters
  my $outputFile = $self->getParamValue('outputFile');
  my $organismSource = $self->getParamValue('organismSource');
  my $deprecated = ($self->getParamValue('deprecated') eq 'true') ? 1 :0;

  my (@dbnames,@dbvers);
  my ($name,$ver) = $self->getExtDbInfo($test, $self->getParamValue('genomeExtDbRlsSpec')) if $self->getParamValue('genomeExtDbRlsSpec');
  push (@dbnames,$name);
  push (@dbvers,$ver);
  ($name,$ver) = $self->getExtDbInfo($test, $self->getParamValue('genomeVirtualSeqsExtDbRlsSpec')) if $self->getParamValue('genomeVirtualSeqsExtDbRlsSpec');
  push (@dbnames,$name);
  push (@dbvers,$ver);
  my $names = join (",",map{"'$_'"} @dbnames);
  my $vers = join (",",map{"'$_'"} @dbvers);

  my $apiSiteFilesDir = $self->getGlobalConfig('apiSiteFilesDir');

  my $sql = <<"EOF";
     SELECT '$organismSource'
                ||'|'||
            gf.source_id
                || decode(gf.is_deprecated, 1, ' | deprecated=true', '')
                ||' | organism='||
            replace( gf.organism, ' ', '_')
                ||' | product='||
            gf.product
                ||' | location='||
            fl.sequence_source_id
                ||':'||
            fl.start_min
                ||'-'||
            fl.end_max
                ||'('||
            decode(fl.is_reversed, 1, '-', '+')
                ||') | length='||
            snas.length
            as defline,
            snas.sequence
           FROM apidb.geneattributes gf,
                dots.transcript t,
                dots.splicednasequence snas,
                apidb.featurelocation fl
      WHERE gf.na_feature_id = t.parent_id
        AND t.na_sequence_id = snas.na_sequence_id
        AND gf.na_feature_id = fl.na_feature_id
        AND gf.so_term_name != 'repeat_region'
        AND gf.external_db_name in ($names)
        AND gf.external_db_version in ($vers)
        AND fl.is_top_level = 1
        AND gf.is_deprecated = $deprecated
EOF

my $cmd = "gusExtractSequences --outputFile $apiSiteFilesDir/$outputFile  --idSQL \"$sql\" --verbose";

  if ($test) {
      $self->runCmd(0,"echo test > $apiSiteFilesDir/$outputFile");
  }

   if ($undo) {
    $self->runCmd(0, "rm -f $apiSiteFilesDir/$outputFile");
  } else {
    $self->runCmd($test,$cmd);
  }

}


sub getParamsDeclaration {
  return (
          'outputFile',
          'organismSource',
          'genomeExtDbRlsSpec',
          'genomeVirtualSeqsExtDbRlsSpec',
	  'deprecated'
         );
}

sub getConfigDeclaration {
  return (
         # [name, default, description]
         # ['', '', ''],
         );
}

