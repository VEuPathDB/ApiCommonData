package ApiCommonData::Load::EBITableReader;
use base qw(ApiCommonData::Load::UniDBTableReader);

use strict;

use Data::Dumper;

$/ = "#EOR#\n";
my $FIELD_DELIMITER = "#EOC#\t";


sub setTableFileHandle { $_[0]->{_table_file_handle} = $_[1] }
sub getTableFileHandle { $_[0]->{_table_file_handle} }

sub setTableHeader { $_[0]->{_table_header} = $_[1] }
sub getTableHeader { $_[0]->{_table_header} }

sub getTableNameFromPackageName {
  my ($self, $fullTableName) = @_;

  $fullTableName =~ /GUS::Model::(.+)::(.+)/i;
  my $tableName = $1 . "." . $2;
  return uc $tableName;
}

sub prepareTable {
  my ($self, $tableName, $isSelfReferencing, $primaryKeyColumn, $maxAlreadyLoadedPk) = @_;

  my $fileName = $self->getTableNameFromPackageName($tableName);

  my $databaseDir = $self->getDatabaseDirectory();

  my $fullFilePath = "$databaseDir/$fileName";

  unless(-e $fullFilePath) {
    $self->setTableFileHandle(undef);
    $self->setTableHeader(undef);
    return;
  }


  my $fh;
  open($fh, $fullFilePath) or die "Cannot open file $fullFilePath: $!";

  my $header = <$fh>;
  chomp $header;

  my @a = split($FIELD_DELIMITER, $header);
  $self->setTableFileHandle($fh);
  $self->setTableHeader(\@a);
}

sub finishTable {
  my ($self) = @_;

  my $fh = $self->getTableFileHandle();

  close $fh if($fh);

  $self->setTableFileHandle(undef);
  $self->setTableHeader(undef);
}

sub nextRowAsHashref {
  my ($self, $tableInfo) = @_; #tableInfo is not used in this context

  my $fh = $self->getTableFileHandle();
  return undef unless($fh);

  my $row = <$fh>;
  chomp $row;

  return undef unless($row);

  my @a = split($FIELD_DELIMITER, $row);

  my $header = $self->getTableHeader();

  my %hash;
  @hash{@$header} = @a;

  return \%hash;
}


sub isRowGlobal {
  my ($self, $mappedRow, $tableName) = @_;

  if($tableName eq "GUS::Model::SRes::DbRef") {
    return 1;
  }

  return 0; 
}

sub skipRow {
  return 0;
}

sub loadRow {
  return 1;
}

sub getDistinctTablesForTableIdField {
  my ($self, $field, $table) = @_;

  print "Field=$field, table=$table\n";

  my $fileName = "CORE.TABLEINFO";
  my $nameField = "name";
  my $tableIdField = "table_id";


  my $outputDir = $self->getDatabaseDirectory();

  my $fullFilePath = "$outputDir/$fileName";
  
  open(FILE, $fullFilePath) or die "Cannot open file $fullFilePath: $!";
  my $header = <FILE>;
  chomp $header;
  my @header = split($FIELD_DELIMITER, $header);

  my ($nameIndex) = grep { lc($header[$_]) eq lc($nameField) } 0 .. $#header;
  my ($tableIdIndex) = grep { lc($header[$_]) eq lc($tableIdField) } 0 .. $#header;
  my %rv;

  if(uc($table) eq "DOTS.GOASSOCIATION") {
    my $softTable = "TranslatedAASequence";
    my $impTable = "AASequenceImp";

    while(<FILE>) {
      chomp;
      my @a = split($FIELD_DELIMITER, $_);

      my $name = $a[$nameIndex];
      my $tableId = $a[$tableIdIndex];

      if($name eq $softTable) {
        $rv{$tableId} = "GUS::Model::DoTS::${impTable}";
      }
    }
    
  }
  else {
    print STDERR "Table $table is not handled for soft keys\n"
  }
  
  close FILE;

  unless(scalar(keys(%rv)) > 0) {
    print STDERR  "Could not identify tables for soft key for $table, $field\n";
  }

  return \%rv;
}



sub getDistinctValuesForField {
  my ($self, $table, $field) = @_;

  my $fileName = $self->getTableNameFromPackageName($table);

  my $outputDir = $self->getDatabaseDirectory();
  my $fullFilePath = "$outputDir/$fileName";

  open(FILE, $fullFilePath) or die "Cannot open file $fullFilePath: $!";

  <FILE>;

  my @header = @{$self->getTableHeader()};
  my ($index) = grep { lc($header[$_]) eq lc($field) } 0 .. $#header;

  my %seen;
  while(<FILE>) {
    chomp;
    my @a = split($FIELD_DELIMITER, $_);
    my $value = $a[$index];
    $seen{$value} = 1;
  }
  close FILE;

  return \%seen;
}


sub getMaxFieldLength {
  my ($self, $table, $field) = @_;

  my $fileName = $self->getTableNameFromPackageName($table);

  my $outputDir = $self->getDatabaseDirectory();
  my $fullFilePath = "$outputDir/$fileName";

  open(FILE, $fullFilePath) or die "Cannot open file $fullFilePath: $!";

  <FILE>;
  my @header = @{$self->getTableHeader()};
  my ($index) = grep { lc($header[$_]) eq lc($field) } 0 .. $#header;

  my $length = 0;
  while(<FILE>) {
    chomp;
    my @a = split($FIELD_DELIMITER, $_);
    my $value = $a[$index];
    my $l = length $value;
    $length = $l if($l > $length);
  }
  close FILE;

  return $length;
}


# not used
sub getTableCount {
  die "";
}


1;
