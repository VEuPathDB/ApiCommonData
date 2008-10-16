package ApiCommonData::Load::Steps::WorkflowSteps::ExtractNaSeq;

@ISA = (GUS::Pipeline::WorkflowStep);

use strict;

use GUS::PluginMgr::Plugin;

sub run {
  my ($self) = @_;

  my $name = $self->getConfig('genomeName');
  
  my $seqType = $self->getConfig('seqType');

  my $table = $self->getConfig('table');
  
  my $identifier = $self->getConfig('identifier');

  my $ncbiTaxId = $self->getConfig('ncbiTaxId');

  my $type = ucfirst($seqType);

  my $dbRlsId = $self->getExtDbRlsId($self->getConfig('genomeExtDbRlsSpec'));

  my $outFile = $self->getConfig('outputFile');

  my $sql = my $sql = "select x.$identifier, x.description,
            'length='||x.length,x.sequence
             from dots.$table x
             where x.external_database_release_id = $dbRlsId";

  my $taxonId = $self->getTaxonId($self->getArg('ncbiTaxId'));

  my $cmd = "gusExtractSequences --outputFile $outFile --idSQL \"$sql\" --verbose 2>> $logFile";

  $self->runCmd($cmd);
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
     ['name', "", ""],
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
