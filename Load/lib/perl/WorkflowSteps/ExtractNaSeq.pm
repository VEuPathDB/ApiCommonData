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

  my $table = $self->getParamValue('table');
  
  my $identifier = $self->getParamValue('identifier');

  my $taxonId = $self->getTaxonId($self->getParamValue('ncbiTaxId'));

  my $dbRlsId = $self->getExtDbRlsId($self->getParamValue('genomeExtDbRlsSpec'));

  my $outputFileOrDir = $self->getParamValue('outputFileOrDir');

  my $separateFastaFiles = $self->getParamValue('separateFastaFiles');

  my $seqfilesDir = $self->getParamValue('seqfilesDir');
  
  $self->runCmd(0, "mkdir -p $seqfilesDir") if $seqfilesDir;
  
  my $sql = "select x.$identifier, x.description,
            'length='||x.length,x.sequence
             from dots.$table x
             where x.external_database_release_id = $dbRlsId";
  my $cmd;

  if ($separateFastaFiles) {

      $cmd="gusExtractIndividualSequences --outputDir $outputFileOrDir --idSQL \"$sql\" --verbose";

  } else {

      $cmd = "gusExtractSequences --outputFile $outputFileOrDir --idSQL \"$sql\" --verbose";
  }
  
  if ($test) {

      $self->runCmd(0,"test > $outputFileOrDir");

  } else {

      $self->runCmd($test,$cmd);

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
