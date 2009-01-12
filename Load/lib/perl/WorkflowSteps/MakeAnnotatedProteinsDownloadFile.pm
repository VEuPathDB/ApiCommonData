package ApiCommonData::Load::WorkflowSteps::MakeAnnotatedProteinsDownloadFile;

@ISA = (ApiCommonData::Load::WorkflowSteps::WorkflowStep);
use strict;
use ApiCommonData::Load::WorkflowSteps::WorkflowStep;

sub run {
  my ($self, $test) = @_;

  # get parameters
  my @extDbNames = map{"'$_'"} split (/,/,$self->getParamValue('extDbName'));
  my @extDbRlss = map{"'$_'"} split (/,/,$self->getParamValue('extDbRls'));
  my $outputFile = $self->getParamValue('outputFile');
  my $deprecated = $self->getParamValue('deprecated') ? 1 : 0;
  my $dataSource = $self->getParamValue('DataSource');

  my $extDbName = join(",", @extDbNames);
  my $extDbRls = join(",", @extDbRlss);
  my $localDataDir = $self->getLocalDataDir();

  my $sql = "SELECT '$dataSource'
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
            taas.length
            as defline,
            taas.sequence
           FROM apidb.featurelocation fl,
                apidb.geneattributes gf,
                dots.transcript t,
                dots.splicednasequence snas,
                dots.translatedaafeature taaf,
                dots.translatedaasequence taas
      WHERE gf.na_feature_id = t.parent_id
        AND t.na_sequence_id = snas.na_sequence_id
        AND gf.na_feature_id = fl.na_feature_id
        AND gf.so_term_name != 'repeat_region'
        AND gf.so_term_name = 'protein_coding'
        AND gf.external_db_name in ($extDbName) AND gf.external_db_version in ($extDbRls)
        AND t.na_feature_id = taaf.na_feature_id
        AND taaf.aa_sequence_id = taas.aa_sequence_id
        AND fl.is_top_level = 1
        AND gf.is_deprecated = $deprecated";

  my $cmd = " gusExtractSequences --outputFile $outputFile  --idSQL \"$sql\"";

  if ($test) {
      $self->runCmd(0, "echo test > $localDataDir/$outputFile");
  } 
  $self->runCmd($test, $cmd);

}

sub getParamsDeclaration {
  return (
          'outputFile',
          'extDbName',
          'extDbRls',
          'deprecated',
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
