package ApiCommonData::Load::Steps::LoadFasta;

@ISA = (GUS::Pipeline::WorkflowStep);

sub run {
  my ($self) = @_;

  my $dataDir = $config->get('dataDir');
  my $file = $config->get('inputFile');
  my $targetTable = $config->get('targetTable');
  my $extDbName = $config->get('extDbName');
  my $extDbRlsVer = $config->get('extDbRlsVer');
  my $soTermName = $config->get('soTermName');
  my $regexSourceId = $config->get('regexSourceId');
  my $check = $config->get('check');
  my $taxId = $config->get('taxId');

  my $inputFile = "$dataDir/seqfiles/$file";

  my $ncbiTaxId = $taxId ? "--ncbiTaxId $taxId" : "";

  my $noCheck = $check eq 'no' ? "--noCheck" : "";

  my $args = "--externalDatabaseName '$extDbName' --externalDatabaseVersion '$extDbRlsVer' --sequenceFile '$inputFile' --SOTermName '$soTermName' $ncbiTaxId --regexSourceId '$regexSourceId' --tableName '$table' $noCheck";

  $self->runPlugin("GUS::Supported::Plugin::LoadFastaSequences", $args);
}

sub restart {
}

sub undo {

}

sub getConfigDeclaration {
  my $configDecl =
    {
      required => ['inputFile', 'targetTable', 'extDbName', 'extDbRlsVer'
		  'soTermName','regexSourceId','check','taxId'],
      optional => []
      };
  return $configDecl;
}

sub getDocumentation {
}
