package ApiCommonData::Load::TuningConfig::Log;

BEGIN {

  # The variable $log is declared inside a BEGIN block.  This makes it behave
  # like a Java "static" variable, whose state persists from one invocation to
  # another.  $log accumulates all the messages posted with addLog().  getlog()
  # returns the value accreted so far.

  my $log;
  my $updateNeededFlag;
  my $updatePerformedFlag;
  my $errorsEncounteredFlag;

  sub addLog {
    my ($message) = @_;

    $log .= "$message\n";
  }

  sub getLog {
    return $log;
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

}

sub addErrorLog {
    my ($message) = @_;

    addLog($message);
    setErrorsEncounteredFlag();
  }

sub mailLog {
  my ($recipientList) = @_;

  my $subject = "tuningManager log: ";

  $subject .= getUpdateNeededFlag() ? "Changes found" : "No changes found";

  $subject .= "; tables updated"
    if getUpdatePerformedFlag();

  $subject .= "; errors encountered"
    if getErrorsEncounteredFlag();

  foreach my $recipient (split(/,/, $recipientList)) {
    open(MAIL, "|mail -s '$subject' $recipient");
    print MAIL getLog();
    close(MAIL);
  }
}

1;
