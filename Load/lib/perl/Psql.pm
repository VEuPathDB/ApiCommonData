package ApiCommonData::Load::Psql;

use strict;

use Data::Dumper;

use File::Temp qw/ tempfile /;

=pod

=head2 ApiCommonData::Load::Psql

=over 4

=item Description

module to manage a Psql

=item Usage

my $psql = ApiCommonData::Load::psql->new({'_login' => 'user',
                                               '_password' => 'pswd', 
                                               '_database' => 'dbname', 
                                               '_dbiDsn' => 'dbiDsn',
                                               '_controlFilePrefix' => 'shortName',
                                               });

$psql->getCommandLine();
$psql->writeConfigFile();

=back

=cut

# DEFAULT VALUES
my $CHARACTER_SET = "UTF8";
my $FIELD_DELIMITER = "\t";
my $NULL_VALUE  = "null";
my $QUOTE_CHARACTER = "`";

sub getQuiet {$_[0]->{_quiet}}
sub setQuiet {$_[0]->{_quiet} = $_[1]}

sub getLogin {$_[0]->{_login}}
sub setLogin {$_[0]->{_login} = $_[1]}

sub getPassword {$_[0]->{_password}}
sub setPassword {$_[0]->{_password} = $_[1]}

sub getDatabase {$_[0]->{_database}}
sub setDatabase {$_[0]->{_database} = $_[1]}

sub getDbiDsn {$_[0]->{_dbiDsn}}
sub setDbiDsn {$_[0]->{_dbiDsn} = $_[1]}

sub getFilePrefix {$_[0]->{_control_file_prefix}}
sub setFilePrefix {$_[0]->{_control_file_prefix} = $_[1]}

sub getLogFileName {$_[0]->{_log_file_name}}
sub setLogFileName {$_[0]->{_log_file_name} = $_[1]}

sub getCharacterSet {$_[0]->{_character_set} || $CHARACTER_SET}
sub setCharacterSet {$_[0]->{_character_set} = $_[1]}

sub getInfileName {$_[0]->{_infile_name}}
sub setInfileName {$_[0]->{_infile_name} = $_[1]}

sub getFieldDelimiter {$_[0]->{_field_delimiter} || $FIELD_DELIMITER}
sub setFieldDelimiter {$_[0]->{_field_delimiter} = $_[1]}

sub getQuoteCharacter {$_[0]->{_quote_character} || $QUOTE_CHARACTER}
sub setQuoteCharacter {$_[0]->{_quote_character} = $_[1]}

sub getNullValue {$_[0]->{_null_value} || $NULL_VALUE}
sub setNullValue {$_[0]->{_null_value} = $_[1]}

sub getTableName {$_[0]->{_table_name}}
sub setTableName {$_[0]->{_table_name} = $_[1]}

sub getFields {$_[0]->{_fields} || []}
sub setFields {$_[0]->{_fields} = $_[1]}

sub addField {
  my ($self, $field, $dataType) = @_;

  push @{$self->{_fields}}, "$field $dataType";
}

sub new {
  my ($class, $args) = @_;

  my @required = ('_login', '_password', '_database', '_dbiDsn');

  foreach(@required) {
    die "missing required value for param $_" unless(defined($args->{$_}));
  }

  my $self = bless $args, $class;

  my $filePrefix = $self->getInfileName();
  my $logFileName = "psqlCopy" . $filePrefix . ".log";
  $self->setLogFileName($logFileName);

  return $self; 
}

sub getCommandLine {
  my ($self) = @_;

  my $login = $self->getLogin();
  my $password = $self->getPassword();
  my $database = $self->getDatabase();
  my $dbiDsn = $self->getDbiDsn();

  $dbiDsn =~ /(:|;)host=((\w|\.)+);?/ ;
  my $hostname = $2;
  my $connectionString = "postgresql://$login:$password\@$hostname/$database";

  my $logFileName = $self->getLogFileName();

  my $quiet = $self->getQuiet() ? '>/dev/null 2>&1' : '';
  my $copyCommand = $self->getCommand();

  return "psql --echo-all --echo-errors --log-file='$logFileName' --command='$copyCommand' $connectionString $quiet"
}

sub getCommand {
  my ($self) = @_;

  my $characterSet = $self->getCharacterSet();

  my $infileName = $self->getInfileName();
  my $tableName = $self->getTableName();

  my $fieldDelimiter = $self->getFieldDelimiter();
  my $quoteCharacter = $self->getQuoteCharacter();
  my $null = $self->getNullValue();


  my $fields = $self->getFields();
  my $fieldsString = join(",", @$fields);

  return "\\COPY $tableName ( $fieldsString )
FROM $infileName
WITH (
  FORMAT CSV,
  DELIMITER \"$fieldDelimiter\",
  QUOTE \"$quoteCharacter\",
  NULL  \"$null\",
  ENCODING $characterSet
)";
}

sub DESTROY {
  my $self = shift;
}

1;



