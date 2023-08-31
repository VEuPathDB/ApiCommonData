package ApiCommonData::Load::InstallSchemaUtils;

use Exporter;
use DBI;

our @ISA= qw( Exporter );
our @EXPORT = qw( runSql dropSchemaSetTables dropSchemaSetPostgres getDbh );

sub getDbh {
  my ($gusconfig, $dbName, $dbHost, $dbVendor) = @_;

  die "illegal dbVendor: $dbVendor" unless $dbVendor eq 'Oracle' || $dbVendor eq 'Postgres';

  my $dbiDsn = $dbVendor eq 'Oracle'? "dbi:Oracle:$dbName" : "dbiDsn=dbi:Pg:dbname=$dbName;host=$host";

  return DBI->connect($dbiDsn,
		      $gusconfig->getDatabaseLogin(),
		      $gusconfig->getDatabasePassword(),
		      { PrintError => 1, RaiseError => 0})
    or die "Can't connect to database: $DBI::errstr\n";
}

sub runSql {
  my ($login, $password, $dbh, $dbVendor, $filePath, $allowFailures, @params) = @_;

  -e $filePath || die "File .sql file '$filePath' does not exist\n";

  if (lc $dbVendor eq 'oracle') {
    &runSqlOracle($login, $password, $dbh->{Name}, $filePath, $allowFailures, @params);
  } elsif (lc $dbVendor eq 'postgres') {
    &runSqlPostgres($login, $password, $dbh->{pg_db}, $dbh->{pg_host}, $filePath, $allowFailures, @params);
  } else { 
    die "Unsupported dbVendor:$dbVendor.";
  }
}

sub runSqlOracle {
  my ($login, $password, $dbName, $fullFile, $allowFailures, @params) = @_;

  my $tmpFile = "/tmp/$file.$$";  # append the process id
  unlink($tmpFile);  # in case of a old one
  my $cmd;
  if (!$allowFailures) {
      $cmd = "echo 'whenever sqlerror exit sql.sqlcode;' > $tmpFile";
      runCmd($cmd, $tmpFile);
  }
  $cmd = "echo 'set echo on;' >> $tmpFile";
  runCmd($cmd, $tmpFile);

  # Turn off the default parameter concat character, which is a period. (Otherwise we'd have to use '&1.' as the parameter macro.)
  # Because we assume, for now, that our parameters are always schema names, their placement is always followed by white space or a period,
  # which is not a valid parameter character, effectively terminating the parameter macro, so we don't need a concat character.
 # $cmd = "echo 'set concat off;' >> $tmpFile";
 # runCmd($cmd, $tmpFile);

  $cmd = "cat $fullFile >> $tmpFile";
  runCmd($cmd, $tmpFile);

  # my $sqlplusParamValuesString = join(" ", @sqlplusParamValues);
  $cmd = "sqlplus $login\@$dbName/$password \@$tmpFile " . join(' ', @params);
  print STDOUT "\n==============================================================\n";
  print STDOUT "Running $tmpFile\n";
  print STDOUT "==============================================================\n";

  runCmd($cmd, $tmpFile);
  unlink($tmpFile);
}

sub runSqlPostgres {
  my ($login, $password, $dbName, $dbHostname, $fullFile, $allowFailures, @params) = @_;
  
  my $psql_params = "";
  my $connectionString = "postgresql://$login:$password\@$dbHostname/$dbName";
  
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
    #print STDERR "\nrunning command: $cmd\n";
    system($cmd);
    my $status = $? >> 8;
    if ($status) {
      unlink($tmpFile) if $cmd =~ /^sqlplus/;
      die "Failed with status '$status' running cmd: \n$cmd\n";
    }
}

sub dropSchemaSetTables {
  my ($dbh, $schemaSet) = @_;

  print STDERR "\nFixing to drop objects in schema set \"$schemaSet\"\n";

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
      print STDERR "running statement: $dropStmtSql\n";
      $dbh->do($dropStmtSql) or die "Can't fetch a drop statement: $DBI::errstr\n";
    } else {
      $objectsToDrop = 0;
    }
  }

}

sub dropSchemaSetOracle {
  my ($dbh, $schemaSet) = @_;

  print STDERR "\nFixing to drop schemas in set \"$schemaSet\"\n";

  my $stmt = $dbh->prepare(<<SQL);
    select 'drop user ' || username || ' cascade'
    from all_users
    where username in ($schemaSet)
SQL

  $stmt->execute() or print STDERR "\n" . $dbh->errstr . "\n";

  while (my ($dropStmtSql) = $stmt->fetchrow_array()) {
    print STDERR "\nrunning statement: $dropStmtSql\n";
    $dbh->do($dropStmtSql) or die "Can't fetch a drop statement: $DBI::errstr\n";
  }
}

sub dropSchemaSetPostgres {
  my ($dbh, @schemaSet) = @_;

  print STDERR "\nFixing to drop schemas in set \"@schemaSet\"\n";

  for my $schema (@schemaSet) {
    my $stmt = $dbh->prepare(<<SQL);
    DROP SCHEMA $schema CASCADE;
SQL

    $stmt->execute() or print STDERR "\n" . $dbh->errstr . "\n";

    while (my ($dropStmtSql) = $stmt->fetchrow_array()) {
      print STDERR "\nrunning statement: $dropStmtSql\n";
      $dbh->do($dropStmtSql) or die "Can't fetch a drop statement: $DBI::errstr\n";
    }
  }
}

1;
