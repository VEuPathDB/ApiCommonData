package ApiCommonData::Load::WorkflowSteps::MakeMixedGenomicDownloadFile;

@ISA = (ApiCommonData::Load::WorkflowSteps::WorkflowStep);
use strict;
use ApiCommonData::Load::WorkflowSteps::WorkflowStep;

sub run {
  my ($self, $test) = @_;

  # get parameters
  my @extDbNames = map{"'$_'"} split (/,/,$self->getParamValue('extDbName'));
  my @extDbRlss = map{"'$_'"} split (/,/,$self->getParamValue('extDbRls'));
  my $outputFile = $self->getParamValue('outputFile');
  my $organismSource = $self->getParamValue('organismSource');
  
  my $apiSiteFilesDir = $self->getGlobalConfig('apiSiteFilesDir');

  my $extDbName = join(",", @extDbNames);
  my $extDbRls = join(",", @extDbRlss);

  my $sql = " SELECT '$organismSource'
                ||'|'||
               sa.source_id
                ||' | organism='||
               replace(sa.organism, ' ', '_')
                ||' | version='||
               sa.database_version
                ||' | length=' ||
               sa.length
               as defline,
               ns.sequence
           FROM dots.nasequence ns,
                apidb.sequenceattributes sa
          WHERE ns.na_sequence_id = sa.na_sequence_id
            AND sa.database_name in ($extDbName) AND sa.database_version in ($extDbRls)
            AND sa.is_top_level = 1";

  my $cmd = "gusExtractSequences --outputFile $apiSiteFilesDir/$outputFile  --idSQL \"$sql\" ";

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
