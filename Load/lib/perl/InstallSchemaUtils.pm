package ApiCommonData::Load::InstallSchemaUtils;

use Exporter;
use DBI;

our @ISA= qw( Exporter );
our @EXPORT = qw( runSql dropSchemaSetTables dropSchemaSetPostgres );

sub runSql {
  my ($login, $password, $db, $dbHostname, $dbVendor, $file, $allowFailures, @params) = @_;
  
  if (lc $dbVendor eq 'oracle') { 
    &runSqlOracle($login, $password, $db, $dbVendor, $file, $allowFailures, @params);
  } elsif (lc $dbVendor eq 'postgres') {
    &runSqlPostgres($login, $password, $db, $dbHostname, $dbVendor, $file, $allowFailures @params);
  } else { 
    die "Unsupported dbVendor:$dbVendor."; 
  }
}

sub runSqlOracle {
  my ($login, $password, $db, $dbVendor, $file, $allowFailures, @params) = @_;

  my $fullFile = "$ENV{GUS_HOME}/lib/sql/apidbschema/$dbVendor/$file";

  -e $fullFile || die "File .sql file '$fullFile' does not exist\n";

  my $tmpFile = "/tmp/$file.$$";  # append the process id
  unlink($tmpFile);  # in case of a old one
  my $cmd;
  if (!$allowFailures) {
      $cmd = "echo 'whenever sqlerror exit sql.sqlcode;' > $tmpFile";
      runCmd($cmd, $tmpFile);
  }
  $cmd = "echo 'set echo on;' >> $tmpFile";
  runCmd($cmd, $tmpFile);

  $cmd = "cat $fullFile >> $tmpFile";
  runCmd($cmd, $tmpFile);

  # my $sqlplusParamValuesString = join(" ", @sqlplusParamValues);
  $cmd = "sqlplus $login\@$db/$password \@$tmpFile " . join(' ', @params);
  print STDOUT "\n==============================================================\n";
  print STDOUT "Running $tmpFile\n";
  print STDOUT "==============================================================\n";

  runCmd($cmd, $tmpFile);
  unlink($tmpFile);
}

sub runSqlPostgres {
  my ($login, $password, $db, $dbHostname, $dbVendor, $file, $allowFailures, @params) = @_;
  
  my $psql_params = "";
  my $connectionString = "postgresql://$login:$password\@$dbHostname/$db";
  
  my $fullFile = "$ENV{GUS_HOME}/lib/sql/apidbschema/$dbVendor/$file";
  -e $fullFile || die "File .sql file '$fullFile' does not exist\n";

  my $cmd;
  if (!$allowFailures) { $psql_params = "-v ON_ERROR_STOP=1"; }

  if (scalar @params > 0) {
    my @paramsFull;
    for(my $i = 0; $i < scalar @params; $i++) {
      my $n = $i +1;
      my $p = "VAR${n}";
      push @paramsFull, "-v ${p}=$params[$i]";
    }

    $psql_params = "$psql_params " . join(" ", @paramsFull);
  }

  $cmd = "psql --echo-all -f $fullFile $psql_params $connectionString";
  print STDOUT "\n==============================================================\n";
  print STDOUT "Running $fullFile\n";
  print STDOUT "==============================================================\n";

  runCmd($cmd, $fullFile);
}

sub runCmd {
    my ($cmd, $tmpFile) = @_;
    print STDERR "\nrunning command: $cmd\n" if $verbose;
    system($cmd);
    my $status = $? >> 8;
    if ($status) {
      unlink($tmpFile) if $cmd =~ /^sqlplus/;
      die "Failed with status '$status running cmd: \n$cmd'\n";
    }
}

sub dropSchemaSetTables {
  my ($login, $password, $db, $schemaSet) = @_;

  my $dsn = "dbi:Oracle:" . $db;
  my $dbh = DBI->connect(
                $dsn,
                $login,
                $password,
                { PrintError => 1, RaiseError => 0}
                ) or die "Can't connect to the database: $DBI::errstr\n";

  print STDERR "\nfixing to drop objectss in schema set \"$schemaSet\"\n" if $verbose;

  # drop everything
  my $stmt = $dbh->prepare(<<SQL);
    select 'drop ' || object_type || ' ' || owner || '.' || object_name
           || decode(object_type, 'TABLE', ' CASCADE CONSTRAINTS', '')
    from all_objects
    where owner in ($schemaSet)
      and object_type not in ('INDEX', 'TRIGGER', 'TYPE BODY')
SQL

  my $objectsToDrop = 1;

  while ($objectsToDrop) {
    $stmt->execute() or print STDERR "\n" . $dbh->errstr . "\n";

    if (my ($dropStmtSql) = $stmt->fetchrow_array()) {
      print STDERR "running statement: $dropStmtSql\n" if $verbose;
      $dbh->do($dropStmtSql) or die "Can't fetch a drop statement: $DBI::errstr\n";
    } else {
      $objectsToDrop = 0;
    }
  }

}

sub dropSchemaSetOracle {
  my ($login, $password, $db, $schemaSet) = @_;

  my $dsn = "dbi:Oracle:" . $db;
  my $dbh = DBI->connect(
                $dsn,
                $login,
                $password,
                { PrintError => 1, RaiseError => 0}
                ) or die "Can't connect to the database: $DBI::errstr\n";

  print STDERR "\nfixing to drop schemas in set \"$schemaSet\"\n" if $verbose;

  my $stmt = $dbh->prepare(<<SQL);
    select 'drop user ' || username || ' cascade'
    from all_users
    where username in ($schemaSet)
SQL

  $stmt->execute() or print STDERR "\n" . $dbh->errstr . "\n";

  while (my ($dropStmtSql) = $stmt->fetchrow_array()) {
    print STDERR "\nrunning statement: $dropStmtSql\n" if $verbose;
    $dbh->do($dropStmtSql) or die "Can't fetch a drop statement: $DBI::errstr\n";
  }
}

sub dropSchemaSetPostgres {
  my ($dbiDsn, $login, $password, $db, @schemaSet) = @_;

  my $dbh = DBI->connect(
                $dbiDsn,
                $login,
                $password,
                { PrintError => 1, RaiseError => 0}
                ) or die "Can't connect to the database: $DBI::errstr\n";

  print STDERR "\nfixing to drop schemas in set \"@schemaSet\"\n" if $verbose;

  for my $schema (@schemaSet) {
    my $stmt = $dbh->prepare(<<SQL);
    DROP SCHEMA $schema CASCADE;
SQL

    $stmt->execute() or print STDERR "\n" . $dbh->errstr . "\n";

    while (my ($dropStmtSql) = $stmt->fetchrow_array()) {
      print STDERR "\nrunning statement: $dropStmtSql\n" if $verbose;
      $dbh->do($dropStmtSql) or die "Can't fetch a drop statement: $DBI::errstr\n";
    }
  }
}

1;
