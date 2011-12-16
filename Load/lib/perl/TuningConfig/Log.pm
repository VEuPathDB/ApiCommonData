package ApiCommonData::Load::TuningConfig::Log;

use ApiCommonData::Load::TuningConfig::TableSuffix;

BEGIN {

  # These variables are declared inside a BEGIN block.  This makes them behave
  # like a Java "static" variable, whose state persists from one invocation to
  # another.  $log accumulates all the messages posted with addLog().  getlog()
  # returns the value accreted so far.

  my $logFile;
  my $logPreamble;
  my $updateNeededFlag;
  my $updatePerformedFlag;
  my $errorsEncounteredFlag;
  my $partialUpdateFlag;
  my $debugFlag;
  my $indentString;
  my $instance;
  my $outOfSpaceMessage;

  sub setLogfile {
    my ($fileName) = @_;
    $logFile = $fileName;
  }

  sub getLogfile {
    return $logFile;
  }

  sub addLog {
    my ($message) = @_;

    my $dateString = `date '+%Y/%m/%d %H:%M:%S'`;
    chomp ($dateString);
    $message =~ s/\n/\n$dateString| $indentString/;
    $message = "$dateString| $indentString$message";

    $| = 1;
    print STDERR "$message\n";

    # if log file name is unset, set it to a default
    $logFile = "/tmp/tuningManager." . $$ . "." . time . ".log"
      if !$logFile;

    open(my $fh, '>>', $logFile) or die "opening logfile \"$logFile\"for appending";
    print $fh "$message\n";
    close($fh);
  }

  sub addLogPreamble {
    my ($message) = @_;

    my $dateString = `date '+%Y/%m/%d %H:%M:%S'`;
    chomp ($dateString);
    $message =~ s/\n/\n$dateString| $indentString/;
    $message = "$dateString| $indentString$message";

    $| = 1;
    print STDERR "$message\n";
    $logPreamble .= "$message\n";
  }

  sub getLog {
    return $logPreamble . `cat $logFile`;
  }

  sub increaseIndent {
    $indentString .= "    ";
  }

  sub decreaseIndent {
    $indentString = substr($indentString, 0, -4);
  }

  sub setDebugFlag {
    $debugFlag = 1;
  }

  sub getDebugFlag {
    return $debugFlag;
  }

  sub setUpdateNeededFlag {
    $updateNeededFlag = 1;
  }

  sub getUpdateNeededFlag {
    return $updateNeededFlag;
  }

  sub setUpdatePerformedFlag {
    $updatePerformedFlag = 1;
  }

  sub getUpdatePerformedFlag {
    return $updatePerformedFlag;
  }

  sub setErrorsEncounteredFlag {
    $errorsEncounteredFlag = 1;
  }

  sub getErrorsEncounteredFlag {
    return $errorsEncounteredFlag;
  }

  sub setPartialUpdatedFlag {
    $partialUpdatedFlag = 1;
  }

  sub getPartialUpdatedFlag {
    return $partialUpdatedFlag;
  }

  sub setInstance {
    my ($givenInstance) = @_;
    $instance = $givenInstance;
  }

  sub getInstance {
    return $instance;
  }

  sub setOutOfSpaceMessage {
    my ($message) = @_;
    $outOfSpaceMessage = $message;
  }

  sub getOutOfSpaceMessage {
    return $outOfSpaceMessage;
  }

}

sub addErrorLog {
    my ($message) = @_;

    addLog("ERROR: " . $message);
    setErrorsEncounteredFlag();
  }

sub addLogBanner {
    my ($message) = @_;

    $message = "### " . $message . " ###";
    my $frame = $message;
    $frame =~ s/./#/g;

    addLog("\n$frame");
    addLog($message);
    addLog($frame);
  }

sub mailLog {
  my ($recipientList, $instance_name) = @_;

  my $subject = "$instance_name - ";

  if (!getUpdateNeededFlag() && !getErrorsEncounteredFlag()) {
    $subject .= 'ok';
  } elsif (getUpdateNeededFlag() && !getUpdatePerformedFlag()) {
    $subject .= 'NEEDS UPDATE';
  } elsif (getUpdatePerformedFlag()) {
    $subject .= "updated";
  }

  $subject .= " - ERRORS"
    if getErrorsEncounteredFlag();

  foreach my $recipient (split(/,/, $recipientList)) {
    if ($recipient && ($recipient ne "none")) {
      open(MAIL, "|mail -s '$subject' $recipient");
      print MAIL getLog();
      close(MAIL);
    }
  }

  unlink(getLogfile());
}

sub getProcessInfo {
  my $nodename = `uname -n`;
  chomp($nodename);
  return("process $$ on $nodename");
}

sub logRebuild {
  my ($dbh, $name, $buildDuration, $instanceName, $dblink, $recordCount) = @_;

  my $suffix = ApiCommonData::Load::TuningConfig::TableSuffix::getSuffix($dbh);
  my $updater = getProcessInfo();

  $dbh->do(<<SQL) or addErrorLog("\n" . $dbh->errstr . "\n");
insert into apidb_r.TuningTableLog\@$dblink
(instance_nickname, name, suffix, updater, timestamp, row_count, build_duration)
select '$instanceName', '$name', '$suffix', '$updater', sysdate, '$recordCount', '$buildDuration'
from dual
SQL

}

sub mailOutOfSpaceReport {

  my ($instance, $dbaEmail, $fromEmail) = @_;

  my $errstr = getOutOfSpaceMessage();
  $errstr =~ /ORA-01652: unable to extend temp segment by .* in tablespace (\S*) /
    or addErrorLog("unsuccessful parsing error message for tablespace name.");
  my $tablespace = $1;

  my $subject = "out of space in instance $instance, tablespace $tablespace";

  ApiCommonData::Load::TuningConfig::Log::addLog("Sending out-of-space notification to \"$dbaEmail\" with subject \"$subject\"");

  open(MAIL, "|mail -s '$subject' $dbaEmail  -- -r $fromEmail");

  print MAIL <<EMAIL;
Dear DBAs,

The tuning manager encountered the error "$errstr" in the instance $instance.

Can that tablespace ($tablespace) be made bigger?

Thanks!

(Note: this email was generated automatically by the tuning manager.)
EMAIL

  close(MAIL);
}

1;
