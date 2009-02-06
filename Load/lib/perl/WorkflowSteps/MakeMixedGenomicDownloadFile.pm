package ApiCommonData::Load::WorkflowSteps::MakeMixedGenomicDownloadFile;

@ISA = (ApiCommonData::Load::WorkflowSteps::WorkflowStep);
use strict;
use ApiCommonData::Load::WorkflowSteps::WorkflowStep;

sub run {
  my ($self, $test, $undo) = @_;

  # get parameters
  my @genomeExtDbSpecList = split (/,/,$self->getParamValue('genomeExtDbSpecList'));
  my $outputFile = $self->getParamValue('outputFile');
  my $organismSource = $self->getParamValue('organismSource');
  
  my $apiSiteFilesDir = $self->getGlobalConfig('apiSiteFilesDir');

  my (@extDbRlsVers,@extDbNames);

  foreach ( @genomeExtDbSpecList ){
      my ($extDbName,$extDbRlsVer)=$self->getExtDbInfo($test,$_);
      push (@extDbNames,$extDbName);
      push (@extDbRlsVers,$extDbRlsVer);
  }

  my $extDbNameList = join(",", map{"'$_'"} @extDbNames);
  my $extDbRlsVerList = join(",",map{"'$_'"} @extDbRlsVers);


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
            AND sa.database_name in ($extDbNameList) AND sa.database_version in ($extDbRlsVerList)
            AND sa.is_top_level = 1";

  my $cmd = "gusExtractSequences --outputFile $apiSiteFilesDir/$outputFile  --idSQL \"$sql\" ";

  if ($test) {
    $self->runCmd(0, "echo test > $apiSiteFilesDir/$outputFile");
  }elsif($undo){
    $self->runCmd(0, "rm -f $apiSiteFilesDir/$outputFile");
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


