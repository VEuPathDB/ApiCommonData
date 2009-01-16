package ApiCommonData::Load::WorkflowSteps::MakeAnnotatedCDSDownloadFile;

@ISA = (ApiCommonData::Load::WorkflowSteps::WorkflowStep);
use strict;
use ApiCommonData::Load::WorkflowSteps::WorkflowStep;


sub run {
  my ($self, $test) = @_;

  # get parameters
  my $outputFile = $self->getParamValue('outputFile');
  my $deprecated = $self->getParamValue('deprecated') ? 1 : 0;
  my $dataSource = $self->getParamValue('dataSource');

  my (@dbnames,@dbvers);
  my ($name,$ver) = $self->getExtDbInfo($test, $self->getParamValue('genomeExtDbRlsSpec')) if $self->getParamValue('genomeExtDbRlsSpec');
  push (@dbnames,$name);
  push (@dbvers,$ver);
  ($name,$ver) = $self->getExtDbRlsId($test, $self->getParamValue('genomeVirtualSeqsExtDbRlsSpec')) if $self->getParamValue('genomeVirtualSeqsExtDbRlsSpec');
  push (@dbnames,$name);
  push (@dbvers,$ver);
  my $names = join (",", @dbnames);
  my $vers = join (",", @dbvers);

  my $apiSiteFilesDir = $self->getGlobalConfig('apiSiteFilesDir');

 my $sql = <<"EOF";
     SELECT '$dataSource'
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
            (fl.start_min + taaf.translation_start - 1)
                ||'-'||
            (fl.end_max - (snas.length - taaf.translation_stop))
                ||'('||
            decode(fl.is_reversed, 1, '-', '+')
                ||') | length='||
            (taaf.translation_stop - taaf.translation_start + 1)
            as defline,
           SUBSTR(snas.sequence,
                  taaf.translation_start,
                  taaf.translation_stop - taaf.translation_start + 1)
           FROM apidb.featurelocation fl,
                apidb.geneattributes gf,
                dots.transcript t,
                dots.splicednasequence snas,
                dots.translatedaafeature taaf
      WHERE gf.na_feature_id = t.parent_id
        AND t.na_sequence_id = snas.na_sequence_id
        AND gf.na_feature_id = fl.na_feature_id
        AND gf.so_term_name != 'repeat_region'
        AND gf.so_term_name = 'protein_coding'
        AND gf.external_db_name in ($names) 
        AND gf.external_db_version in ($vers)
        AND t.na_feature_id = taaf.na_feature_id
        AND fl.is_top_level = 1
        AND gf.is_deprecated = $deprecated
EOF


   my $cmd = <<"EOF";
      gusExtractSequences --outputFile $apiSiteFilesDir/$outputFile \\
      --idSQL \"$sql\" \\
      --verbose
EOF

  if ($test) {
      $self->runCmd(0,"echo test > $apiSiteFilesDir/$outputFile");
  }

  $self->runCmd($test,$cmd);
}

sub getParamsDeclaration {
  return (
          'outputFile',
          'organismSource',
          'genomeExtDbRlsSpec',
          'projectDB',
         );
}

sub getConfigDeclaration {
  return (
         # [name, default, description]
         # ['', '', ''],
         );
}

sub restart {
}

sub undo {

}

sub getDocumentation {
}
