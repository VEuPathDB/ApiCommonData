package ApiCommonData::Load::Sqlldr;

use strict;

use Data::Dumper;

use File::Temp qw/ tempfile /;

=pod

=head2 ApiCommonData::Load::Sqlldr

=over 4

=item Description

module to manage  a Sqlldr

=item Usage

my $sqlldr = ApiCommonData::Load::Sqlldr->new({'_login' => 'user', 
                                               '_password' => 'pswd', 
                                               '_database' => 'dbname', 
                                               '_direct' => 1|0, 
                                               '_controlFilePrefix' => 'shortName',
                                               });

$sqlldr->getCommandLine();
$sqlldr->wrietControlFile();

=back

=cut

# DEFAULT VALUES
my $ROWS = 100000;
my $BIND_SIZE = 512000;
my $READ_SIZE = 512000;
my $DISCARD_MAX = 0;
my $ERROR_COUNT = 0;
my $STREAM_SIZE = 512000;
my $SKIP_INDEX_MAINTENANCE = 0;
my $CHARACTER_SET = "UTF8";
my $LENGTH_SEMANTICS = "CHAR";
my $LINE_DELIMITER = "\\n";
my $FIELD_DELIMITER = "\\t";
my $APPEND = 1;

sub getQuiet {$_[0]->{_quiet}}
sub setQuiet {$_[0]->{_quiet} = $_[1]}

sub getLogin {$_[0]->{_login}}
sub setLogin {$_[0]->{_login} = $_[1]}

sub getPassword {$_[0]->{_password}}
sub setPassword {$_[0]->{_password} = $_[1]}

sub getDatabase {$_[0]->{_database}}
sub setDatabase {$_[0]->{_database} = $_[1]}

sub getControlFileName {$_[0]->{_control_file_name}}
sub setControlFileName {$_[0]->{_control_file_name} = $_[1]}

sub getControlFilePrefix {$_[0]->{_control_file_prefix}}
sub setControlFilePrefix {$_[0]->{_control_file_prefix} = $_[1]}

sub getControlFileHandle {$_[0]->{_control_file_handle}}
sub setControlFileHandle {$_[0]->{_control_file_handle} = $_[1]}

sub getRows {$_[0]->{_rows} || $ROWS}
sub setRows {$_[0]->{_rows} = $_[1]}

sub getBindSize {$_[0]->{_bind_size} || $BIND_SIZE}
sub setBindSize {$_[0]->{_bind_size} = $_[1]}

sub getReadSize {$_[0]->{_read_size} || $READ_SIZE}
sub setReadSize {$_[0]->{_read_size} = $_[1]}

sub getLogFileName {$_[0]->{_log_file_name}}
sub setLogFileName {$_[0]->{_log_file_name} = $_[1]}

sub getDiscardMax {$_[0]->{_discard_max} || $DISCARD_MAX}
sub setDiscardMax {$_[0]->{_discard_max} = $_[1]}

sub getErrorCount {$_[0]->{_error_count} || $ERROR_COUNT}
sub setErrorCount {$_[0]->{_error_count} = $_[1]}

sub getStreamSize {$_[0]->{_stream_size} || $STREAM_SIZE}
sub setStreamSize {$_[0]->{_stream_size} = $_[1]}

sub getDirect {$_[0]->{_direct}}
sub setDirect {$_[0]->{_direct} = $_[1]}

sub getSkipIndexMaintenance {$_[0]->{_skip_index_maintenance} || $SKIP_INDEX_MAINTENANCE}
sub setSkipIndexMaintenance {$_[0]->{_skip_index_maintenance} = $_[1]}

sub getUnrecoverable {$_[0]->{_unrecoverable}}
sub setUnrecoverable {$_[0]->{_unrecoverable} = $_[1]}

sub getCharacterSet {$_[0]->{_character_set} || $CHARACTER_SET}
sub setCharacterSet {$_[0]->{_character_set} = $_[1]}

sub getLengthSemantics {$_[0]->{_length_semantics} || $LENGTH_SEMANTICS}
sub setLengthSemantics {$_[0]->{_length_semantics} = $_[1]}

sub getInfileName {$_[0]->{_infile_name}}
sub setInfileName {$_[0]->{_infile_name} = $_[1]}

sub getLineDelimiter {$_[0]->{_line_delimiter} || $LINE_DELIMITER}
sub setLineDelimiter {$_[0]->{_line_delimiter} = $_[1]}

sub getFieldDelimiter {$_[0]->{_field_delimiter} || $FIELD_DELIMITER}
sub setFieldDelimiter {$_[0]->{_field_delimiter} = $_[1]}

sub getAppend {$_[0]->{_append} || $APPEND}
sub setAppend {$_[0]->{_append} = $_[1]}

sub getTableName {$_[0]->{_table_name}}
sub setTableName {$_[0]->{_table_name} = $_[1]}

sub getReenableDisabledConstraints {$_[0]->{_reenable_disabled_constraints}}
sub setReenableDisabledConstraints {$_[0]->{_reenable_disabled_constraints} = $_[1]}

sub getTrailingNullCols {$_[0]->{_trailing_null_cols}}
sub setTrailingNullCols {$_[0]->{_trailing_null_cols} = $_[1]}

sub getFields {$_[0]->{_fields} || []}
sub setFields {$_[0]->{_fields} = $_[1]}
sub addField {
  my ($self, $field, $dataType) = @_;

  push @{$self->{_fields}}, "$field $dataType";
}



sub new {
  my ($class, $args) = @_;

  my @required = ('_login', '_password', '_database', '_direct', '_controlFilePrefix');

  foreach(@required) {
    die "missing required value for param $_" unless(defined($args->{$_}));
  }

  my $self = bless $args, $class;

  my $controlFilePrefix = $self->getControlFilePrefix();

  my ($fh, $fn) = tempfile("${controlFilePrefix}XXXX", UNLINK => 0, SUFFIX => '.ctl');

  $self->setControlFileName($fn);
  $self->setControlFileHandle($fh);

  my $logFileName = $fn . ".log";
  $self->setLogFileName($logFileName);

  return $self; 
}


sub getCommandLine {
  my ($self) = @_;

  my $login = $self->getLogin();
  my $password = $self->getPassword();
  my $database = $self->getDatabase();

  my $controlFileName = $self->getControlFileName();
  my $logFileName = $self->getLogFileName();

  my $rows = $self->getRows();
  my $bindSize = $self->getBindSize();
  my $readSize = $self->getReadSize();
  my $discardMax = $self->getDiscardMax();
  my $errorCount = $self->getErrorCount();
  my $streamSize = $self->getStreamSize();

  my $skipIndexMaintenance = $self->getSkipIndexMaintenance() ? 'true' : 'false';

  my $quiet = $self->getQuiet() ? '>/dev/null 2>&1' : '';

  if($self->getDirect()) {
    return "sqlldr $login/$password\@$database control=$controlFileName streamsize=$streamSize direct=TRUE skip_index_maintenance=$skipIndexMaintenance log=$logFileName discardmax=$discardMax errors=$errorCount $quiet"
  }

  return "sqlldr $login/$password\@$database control=$controlFileName rows=$rows bindsize=$bindSize readsize=$readSize log=$logFileName discardmax=$discardMax errors=$errorCount $quiet"
}

sub writeConfigFile {
  my ($self) = @_;

  my $characterSet = $self->getCharacterSet();
  my $lengthSemantics = $self->getLengthSemantics();

  my $infileName = $self->getInfileName();
  my $tableName = $self->getTableName();

  my $lineDelimiter = $self->getLineDelimiter();
  my $fieldDelimiter = $self->getFieldDelimiter();

  # make sure common line and field delimiters are printed correctly
  $lineDelimiter =~ s/\n/\\n/;
  $fieldDelimiter =~ s/\t/\\t/;

  my $unrecoverable = $self->getUnrecoverable() ? "UNRECOVERABLE\n" : "";
  my $reenableDisabledConstraints = $self->getReenableDisabledConstraints() ? "REENABLE DISABLED_CONSTRAINTS\n" : "";
  my $append = $self->getAppend() ? "APPEND\n" : "";

  my $fields = $self->getFields();
  my $fieldsString = join(",\n", @$fields);

  my $controlFileHandle = $self->getControlFileHandle();

  print $controlFileHandle "${unrecoverable}LOAD DATA
CHARACTERSET $characterSet LENGTH SEMANTICS $lengthSemantics
INFILE '$infileName' \"str '$lineDelimiter'\"
${append}INTO TABLE $tableName
${reenableDisabledConstraints}FIELDS TERMINATED BY '$fieldDelimiter'
TRAILING NULLCOLS
($fieldsString
)
";

}


sub DESTROY {
  my $self = shift;
  print STDERR "Closing file handles\n";

  my $controlFileHandle = $self->getControlFileHandle();
  my $controlFileName = $self->getControlFileName();

  close $controlFileHandle;

  unlink $controlFileName;
}



1;
