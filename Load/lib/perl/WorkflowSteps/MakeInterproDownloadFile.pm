package ApiCommonData::Load::WorkflowSteps::MakeInterproDownloadFile;

@ISA = (ApiCommonData::Load::WorkflowSteps::WorkflowStep);
use strict;
use ApiCommonData::Load::WorkflowSteps::WorkflowStep;


sub run {
  my ($self, $test) = @_;

  my $outputFile = $self->getParamValue('outputFile');
  my $genomeDbRlsId = $self->getExtDbRlsId($test,$self->getParamValue('genomeExtDbRlsSpec'));
  my $interproDbRlsId = $self->getExtDbRlsId($test,$self->getParamValue('interproExtDbRlsSpec'));
  my $apiSiteFilesDir = $self->getGlobalConfig('apiSiteFilesDir');

  my $sql = <<"EOF";
  SELECT gf.source_id
           || chr(9) ||
         xd1.name
           || chr(9) ||
         dr.primary_identifier
           || chr(9) ||
         dr.secondary_identifier
           || chr(9) ||
         al.start_min
           || chr(9) ||
         al.end_min
           || chr(9) ||
         to_char(df.e_value,'9.9EEEE')
  FROM
    dots.aalocation al,
    sres.dbref dr,
    dots.DbRefAAFeature draf, 
    dots.domainfeature df, 
    dots.genefeature gf,
    dots.transcript t, 
    dots.translatedaafeature taf,
    dots.translatedaasequence tas 
  WHERE
   gf.external_database_release_id = $genomeDbRlsId
     AND gf.na_feature_id = t.parent_id 
     AND t.na_feature_id = taf.na_feature_id 
     AND taf.aa_sequence_id = tas.aa_sequence_id 
     AND tas.aa_sequence_id = df.aa_sequence_id 
     AND df.aa_feature_id = draf.aa_feature_id  
     AND draf.db_ref_id = dr.db_ref_id 
     AND df.aa_feature_id = al.aa_feature_id 
     AND df.external_database_release_id =  $interproDbRlsId
EOF


  my $cmd = <<"EOF";
     makeFileWithSql --outFile $apiSiteFilesDir/$outputFile \\
     --sql \"$sql\"
EOF

  if ($test) {
      $self->runCmd(0,"echo test > $apiSiteFilesDir/$outputFile");
  }

  $self->runCmd($test,$cmd);
}

sub getParamsDeclaration {
  return (
          'outputFile',
          'genomeExtDbRlsSpec',
          'interproExtDbRlsSpec'
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
