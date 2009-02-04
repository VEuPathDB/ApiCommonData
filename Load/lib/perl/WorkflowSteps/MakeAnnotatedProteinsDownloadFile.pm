package ApiCommonData::Load::WorkflowSteps::MakeAnnotatedProteinsDownloadFile;

@ISA = (ApiCommonData::Load::WorkflowSteps::WorkflowStep);
use strict;
use ApiCommonData::Load::WorkflowSteps::WorkflowStep;

sub run {
  my ($self, $test) = @_;

  # get parameters
  my @genomeExtDbSpecList = map{"'$_'"} split (/,/,$self->getParamValue('genomeExtDbSpecList'));
  my $outputFile = $self->getParamValue('outputFile');
  my $deprecated = $self->getParamValue('deprecated') ? 1 : 0;
  my $organismSource = $self->getParamValue('organismSource');

  my $apiSiteFilesDir = $self->getGlobalConfig('apiSiteFilesDir');

  my @extDbRlsVers; 
  my @extDbNames;

  foreach ( @genomeExtDbSpecList ){
      my ($extDbName,$extDbRlsVer)=$self->getExtDbInfo($test,$_);
      push (@extDbNames,$extDbName);
      push (@extDbRlsVers,$extDbRlsVer);
  }

  my $extDbName = join(",", @extDbNames);
  my $extDbRlsVer = join(",", @extDbRlsVers);


  my $sql = "SELECT '$organismSource'
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
        AND gf.external_db_name in ($extDbName) AND gf.external_db_version in ($extDbRlsVer)
        AND t.na_feature_id = taaf.na_feature_id
        AND taaf.aa_sequence_id = taas.aa_sequence_id
        AND fl.is_top_level = 1
        AND gf.is_deprecated = $deprecated";

  my $cmd = " gusExtractSequences --outputFile $apiSiteFilesDir/$outputFile  --idSQL \"$sql\"";

  if ($test) {
      $self->runCmd(0, "echo test > $apiSiteFilesDir/$outputFile");
  }else{
       $self->runCmd($test, $cmd);
   }

}

sub getParamsDeclaration {
  return (
          'outputFile',
          'extDbName',
          'extDbRls',
          'deprecated',
          'apiSiteFilesDir',
	  'organismSource',
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
