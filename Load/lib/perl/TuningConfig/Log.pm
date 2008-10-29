package ApiCommonData::Load::TuningConfig::Log;

BEGIN {

  # These variables are declared inside a BEGIN block.  This makes them behave
  # like a Java "static" variable, whose state persists from one invocation to
  # another.  $log accumulates all the messages posted with addLog().  getlog()
  # returns the value accreted so far.

  my $log;
  my $updateNeededFlag;
  my $updatePerformedFlag;
  my $errorsEncounteredFlag;
  my $partialUpdateFlag;
  my $indentString;

  sub addLog {
    my ($message) = @_;

    $message =~ s/\n/\n$indentString/;
    $message = $indentString . $message;

    $| = 1;
    print "$message\n";
    $log .= "$message\n";
  }

  sub getLog {
    return $log;
  }

  sub increaseIndent {
    $indentString .= "    ";
  }

  sub decreaseIndent {
    $indentString = substr($indentString, 0, -4);
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

  if (!getUpdateNeededFlag()) {
    $subject .= 'ok';
  } elsif (getUpdateNeededFlag() && !getUpdatePerformedFlag()) {
    $subject .= 'NEEDS UPDATE';
  } elsif (getUpdatePerformedFlag()) {
    $subject .= "updated";
  }

  $subject .= " - ERRORS"
    if getErrorsEncounteredFlag();

  foreach my $recipient (split(/,/, $recipientList)) {
    open(MAIL, "|mail -s '$subject' $recipient");
    print MAIL getLog();
    close(MAIL);
  }
}

sub getProcessInfo {
  my $nodename = `uname -n`;
  chomp($nodename);
  return("process $$ on $nodename");
}

1;
