package ApiCommonData::Load::UniDBTableReader;


sub getDatabase {$_[0]->{_database}}

sub new {
  my ($class, $database, $forceSkipDatasetFile, $forceLoadDatasetFile) = @_;
	my $obj = {
		_database => $database,
		_force_skip_datasets => &readListFromFile($forceSkipDatasetFile),
		_force_load_datasets => &readListFromFile($forceLoadDatasetFile),
	};
  return bless $obj, $class;
}

sub readListFromFile {
	my ($self, $file) = @_;
	return [] unless($file && -e $file);
	open(FH, "<$file") or die "Cannot read $file:$!\n";
	my @list = <FH>;
	close(FH);
	chomp @list;
	return \@list;
}

sub connectDatabase {}

sub disconnectDatabase {}

sub prepareTable {}

sub finishTable {}

sub nextRowAsHashref {}

sub isRowGlobal {}

sub skipRow {}
sub loadRow {}


=head2 Helpers for Caching Foreign Keys

=over 4

=item C<getDistinctTablesForTableIdField>

Soft Key Helper.  For a field which is a foreign key to Core::TableInfo, get distinct table_id->TableName mappings

B<Parameters:>

 $self(TableReader): a table reader object
 $field(string): database filed which is a fk to Core::TableInfo (example query_table_id)
 $table(string): database table name like "DoTS.Similarity"

B<Return type:> 

 C<hashref> key is table_id and value is gus model table string.  example:  GUS::Model::DoTS::Similarity

=cut

sub getDistinctTablesForTableIdField {}


=item C<getDistinctValuesForField>

Foreign Key Helper.  For a table and field, lookup distinct possible values and return a hash

B<Parameters:>

 $self(TableReader): a table reader object
 $table(string): gus model table string.  example:  GUS::Model::DoTS::Similarity
 $field(string): this field is a foreign key field in the gus $table

B<Return type:> 

 C<hash> $seen{$id} = 1;

=cut

sub getDistinctValuesForField {}


=item C<getMaxFieldLength>

For memory allocation we need to know the biggest possible length for the field

B<Parameters:>

 $self(TableReader): a table reader object
 $table(string): gus model table string.  example:  GUS::Model::DoTS::Similarity
 $field(string): field name

B<Return type:> 

 C<hash> $length

=cut

sub getMaxFieldLength {}


=item C<getTableCount>

count how many rows are in the table with primary key value <= some value

B<Parameters:>

 $self(TableReader): a table reader object
 $fullTableName(string): gus model table string.  example:  GUS::Model::DoTS::Similarity
 $primaryKeyColumn(string): name of of the primary key field
 $maxPrimaryKey(number): do not count rows with pk greater than this value

B<Return type:> 

 C<number> $count

=cut

sub getTableCount {}


1;
