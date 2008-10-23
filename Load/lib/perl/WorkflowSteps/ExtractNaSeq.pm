package ApiCommonData::Load::WorkflowSteps::ExtractNaSeq;

@ISA = (GUS::Workflow::WorkflowStepInvoker);

use strict;
use GUS::Workflow::WorkflowStepInvoker;


## to do
## API $self->getExtDbRlsId($genomeExtDbRlsSpec)
## API $self->getTaxonId($ncbiTaxId) 
## re-define dataDir

sub run {
  my ($self, $test) = @_;

  my $genomeName = $self->getParamValue('genomeName');
  
  my $seqType = $self->getParamValue('seqType');

  my $table = $self->getParamValue('table');
  
  my $identifier = $self->getParamValue('identifier');

  my $ncbiTaxId = $self->getParamValue('ncbiTaxId');

  my $dbRlsId = $self->getExtDbRlsId($self->getParamValue('genomeExtDbRlsSpec'));

  my $outFile = $self->getParamValue('outputFile');

  my $seqfilesDir = $self->getParamValue('seqfilesDir');

  my $dataDir = $self->getGlobalConfig('dataDir');

  my $projectName = $self->getGlobalConfig('projectName');
 
  my $projectVersion = $self->getGlobalConfig('projectVersion');

  $seqfilesDir = "$dataDir/$projectName/$projectVersion/data/$genomeName/$seqfilesDir";
  
  $outFile = "$seqfilesDir/$outFile";

  my $logFile = "$dataDir/$projectName/$projectVersion/logs/$genomeName/Extract$name-$seqType.log";

  $self->runCmd(0, "mkdir -p $seqfilesDir") if $seqfilesDir;
  
  my $sql = my $sql = "select x.$identifier, x.description,
            'length='||x.length,x.sequence
             from dots.$table x
             where x.external_database_release_id = $dbRlsId";

  my $taxonId = $self->getTaxonId($self->getParamValue('ncbiTaxId'));

  my $cmd = "gusExtractSequences --outputFile $outFile --idSQL \"$sql\" --verbose 2>> $logFile";
  if ($test) {

      $self->runCmd($test,$cmd);
  } else {
      $self->runCmd(0,"test > $outFile");
  }

}


sub getTaxonId {
  my ($self,$ncbiTaxId) = @_;
  my $taxon = GUS::Model::SRes::Taxon->new({ncbi_tax_id => $ncbiTaxId});

  unless ($taxon->retrieveFromDB()) {
    die "$ncbiTaxId not found in sres.taxon.ncbi_tax_id\n";
  }

  my $taxonId = $taxon->getId();

  return $taxonId;
}

sub restart {
}

sub undo {

}

sub getConfigDeclaration {
  my @properties = 
    (
     # [name, default, description]
     ['genomeName', "", ""],
     ['seqType', "", ""],
     ['table', "", ""],
     ['identifier', "", ""],
     ['ncbiTaxId', "", ""],
     ['genomeExtDbRlsSpec', "", ""],
     ['outputFile', "", ""],
    );
  return @properties;
}

sub getDocumentation {
}
