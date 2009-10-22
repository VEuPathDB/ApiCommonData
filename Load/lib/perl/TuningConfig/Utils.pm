package ApiCommonData::Load::TuningConfig::Utils;

use ApiCommonData::Load::TuningConfig::Log;

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

    $sqlReturn = $stmt->execute();

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

1;
