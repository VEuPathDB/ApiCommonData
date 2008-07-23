package ApiCommonData::Load::Steps::LoadFasta;

@ISA = (GUS::Pipeline::WorkflowStep);

sub run {
  my ($self) = @_;

  my $dataDir = $self->getConfig('dataDir');
  my $file = $self->getConfig('inputFile');
  my $targetTable = $self->getConfig('targetTable');
  my $extDbName = $self->getConfig('extDbName');
  my $extDbRlsVer = $self->getConfig('extDbRlsVer');
  my $soTermName = $self->getConfig('soTermName');
  my $regexSourceId = $self->getConfig('regexSourceId');
  my $check = $self->getConfig('check');
  my $taxId = $self->getConfig('taxId');

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
  my @properties = 
    (
     # [name, default, description]
     ['inputFile', "", ""],
     ['targetTable', ],
     ['extDbName', ],
     ['extDbRlsVer', ],
     ['soTermName', ],
     ['regexSourceId', ],
     ['check', ],
     ['taxId' ],
    );
  return @properties;
}

sub getDocumentation {
}
