package ApiCommonData::Load::TuningConfig::Log;

BEGIN {

  # The variable $log is declared inside a BEGIN block.  This makes it behave
  # like a Java "static" variable, whose state persists from one invocation to
  # another.  $log accumulates all the messages posted with addLog().  getlog()
  # returns the value accreted so far.
  my $log;

  sub addLog {
    my ($message) = @_;

    $log .= $message . "\n";
  }

  sub getLog {

    return $log;
  }
}

sub mailLog {
  my ($recipientList) = @_;

  foreach my $recipient (split(/,/, $recipientList)) {
    open(MAIL, "|mail -s 'tuningManager log' $recipient");
    print MAIL getLog();
    close(MAIL);
  }
}

1;
