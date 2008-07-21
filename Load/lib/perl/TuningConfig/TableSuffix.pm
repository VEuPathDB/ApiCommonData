package ApiCommonData::Load::TuningConfig::TableSuffix;

use ApiCommonData::Load::TuningConfig::Log;

BEGIN {

  # The variable $suffix is declared inside a BEGIN block.  This makes it behave
  # like a Java "static" variable, whose state persists from one invocation to
  # another.

  my $suffix;

  sub getSuffix {

    my ($dbh) = @_;

    if (!defined $suffix) {

      my $sql = <<SQL;
       select apidb.TuningManager_sq.nextval from dual
SQL

      my $stmt = $dbh->prepare($sql);
      $stmt->execute()
	or ApiCommonData::Load::TuningConfig::Log::addErrorLog($dbh->errstr);
      ($suffix) = $stmt->fetchrow_array();
      $stmt->finish();

      ApiCommonData::Load::TuningConfig::Log::addLog("    Creating tuning tables with the suffix $suffix");

    }

    return $suffix;
  }
}

1;
