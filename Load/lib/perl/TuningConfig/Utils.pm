package ApiCommonData::Load::TuningConfig::Utils;


use DBI;
use ApiCommonData::Load::TuningConfig::Log;
use XML::Simple;

sub sqlBugWorkaroundDo {

  my ($dbh, $sql) = @_;

  my $attempts = 0;
  my $SQL_RETRIES = 10;
  my $thisSqlWorked;
  my $sqlReturn;

  do {

    $attempts++;
    ApiCommonData::Load::TuningConfig::Log::addLog("retrying -- \$attemps $attempts, \$SQL_RETRIES $SQL_RETRIES")
      if $attempts > 1;

    my $debug = ApiCommonData::Load::TuningConfig::Log::getDebugFlag();

    my ($sec,$min,$hour,$mday,$mon,$year) = localtime();
    my $timestamp = sprintf('%02d:%02d:%02d', $hour, $min, $sec);
    ApiCommonData::Load::TuningConfig::Log::addLog("executing sql at $timestamp")
	if $debug;

    $sqlReturn = $dbh->do($sql);

    ApiCommonData::Load::TuningConfig::Log::addLog("sql returned \"$sqlReturn\"; \$dbh->errstr = \"" . $dbh->errstr . "\"")
	if $debug;

    if (defined $sqlReturn) {
      $thisSqlWorked = 1;
    } else {
      $thisSqlWorked = 0;
      ApiCommonData::Load::TuningConfig::Log::addErrorLog("\n" . $dbh->errstr . "\n");
    }


  } until $thisSqlWorked
    or ($dbh->errstr !~ /ORA-03135/)
      or ($attempts == $SQL_RETRIES);

  return $sqlReturn;
}

sub sqlBugWorkaroundExecute {

  my ($dbh, $stmt) = @_;

  my $attempts = 0;
  my $SQL_RETRIES = 10;
  my $thisSqlWorked;
  my $sqlReturn;

  do {

    $attempts++;
    addLog("retrying -- \$attemps $attempts, \$SQL_RETRIES $SQL_RETRIES")
      if $attempts > 1;

    my $debug = ApiCommonData::Load::TuningConfig::Log::getDebugFlag();

    my ($sec,$min,$hour,$mday,$mon,$year) = localtime();
    my $timestamp = sprintf('%02d:%02d:%02d', $hour, $min, $sec);
    ApiCommonData::Load::TuningConfig::Log::addLog("executing sql at $timestamp")
	if $debug;

    eval {
      $sqlReturn = $stmt->execute();
    };

    # log any errors inside eval
    ApiCommonData::Load::TuningConfig::Log::addErrorLog($@)
	if $@;

    ApiCommonData::Load::TuningConfig::Log::addLog("sql returned \"$sqlReturn\"; \$dbh->errstr = \"" . $dbh->errstr . "\"")
	if $debug;

    if (defined $sqlReturn) {
      $thisSqlWorked = 1;
    } else {
      $thisSqlWorked = 0;
      ApiCommonData::Load::TuningConfig::Log::addErrorLog("\n" . $dbh->errstr . "\n");
    }


  } until $thisSqlWorked
    or ($dbh->errstr !~ /ORA-03135/)
      or ($attempts == $SQL_RETRIES);

  return $sqlReturn;
}

sub getDbLoginInfo {
  my ($instance, $propFile, $username, $password) = @_;
  my $props;

if ($propFile) {
  my $simple = XML::Simple->new();
  $props = $simple->XMLin($propFile);
}

  $password = $props->{password} if !$password;
  $username = $props->{schema} if !$username;
  $username = 'ApidbTuning' if !$username;

  return ($instance, $username, $password);
}

sub getDbHandle {
  my ($instance, $username, $password) = @_;
  my $props;


  my $dsn = "dbi:Oracle:" . $instance;
  my $dbh = DBI->connect(
                $dsn,
                $username,
                $password,
                { PrintError => 1, RaiseError => 0}
                ) or die "Can't connect to the database: $DBI::errstr\n";
  $dbh->{LongReadLen} = 1000000;
  $dbh->{LongTruncOk} = 1;
  print "db info:\n  dsn=$instance\n  login=$username\n\n" if $debug;
  return $dbh;
}

1;
