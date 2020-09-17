package ApiCommonData::Load::GUSTableReader;
use base qw(ApiCommonData::Load::UniDBTableReader);

use strict;

use DBI;
use DBD::Oracle;

use Data::Dumper;

use GUS::Supported::GusConfig;


my @skipDatasets = (
  'metadata.ISA%',
  'ReactionsXRefs_%',
  'metaboliteProfiles%',
  'MetaboliteProfiles%',
  'Pathways_%',
  '%_PostLoadGenome.genomeAnalysis.loadOrfFile',
);

my @globalDatasets = (
  'global.%',
  'EcNumberGenus_RSRC.runPlugin',
  'metadata.ontologySynonyms.Ontology_Synonyms_genbankIsolates_RSRC.runPlugin',
);

sub setDatabaseHandle { $_[0]->{_database_handle} = $_[1] }
sub getDatabaseHandle { $_[0]->{_database_handle} }

sub setStatementHandle { $_[0]->{_statement_handle} = $_[1] }
sub getStatementHandle { $_[0]->{_statement_handle} }

sub getTableNameFromPackageName {
  my ($self, $fullTableName) = @_;

  $fullTableName =~ /GUS::Model::(.+)::(.+)/i;
  return $1 . "." . $2;
}


sub readClob {
  my ($self, $lobLocator) = @_;

  my $dbh = $self->getDatabaseHandle();

  my $chunkSize = $self->{_lob_locator_size};

  unless($chunkSize) {
    $self->{_lob_locator_size} = $dbh->ora_lob_chunk_size($lobLocator);
    $chunkSize = $self->{_lob_locator_size};
  }

  my $offset = 1;   # Offsets start at 1, not 0

  my $output;

  while(1) {
    my $data = $dbh->ora_lob_read($lobLocator, $offset, $chunkSize );
    last unless length $data;
    $output .= $data;
    $offset += $chunkSize;
  }

  return $output;
}


sub getTableSql {
  my ($self, $tableName, $isSelfReferencing, $primaryKeyColumn, $maxAlreadyLoadedPk) = @_;

  $tableName = $self->getTableNameFromPackageName($tableName);


  my $orderBy = $isSelfReferencing ? "order by $primaryKeyColumn" : "";

  if(lc($tableName) eq "sres.ontologyterm") {
    $orderBy = "order by case when ancestor_term_id = ontology_term_id then 0 else 1 end";
  }
  if(lc($tableName) eq "core.tableinfo") {
    $orderBy = "order by view_on_table_id nulls first, superclass_table_id nulls first, table_id";
  }
  
  if(lc($tableName) eq "study.study") {
    $orderBy = "order by investigation_id nulls first, study_id";
  }
  if(lc($tableName) eq "sres.taxon") {
    $orderBy = "start with parent_id is null connect by PRIOR taxon_id = parent_id";
  }

  my $where = "where $primaryKeyColumn > $maxAlreadyLoadedPk";


  my $sql = "select * from $tableName $where $orderBy";

  return $sql;
}

sub prepareTable {
  my ($self, $tableName, $isSelfReferencing, $primaryKeyColumn, $maxAlreadyLoadedPk) = @_;

  my $dbh = $self->getDatabaseHandle();

  $self->{_lob_locator_size} = undef;

  my $sql = $self->getTableSql($tableName, $isSelfReferencing, $primaryKeyColumn, $maxAlreadyLoadedPk);

  my $sh = $dbh->prepare($sql, { ora_auto_lob => 0 } ) 
      or die "Can't prepare SQL statement: " . $dbh->errstr();
  $sh->execute();

  $self->setStatementHandle($sh);
}

sub finishTable {
  my ($self) = @_;

  my $sh = $self->getStatementHandle();
  $sh->finish();
}

sub nextRowAsHashref {
  my ($self, $tableInfo) = @_;
  my $sh = $self->getStatementHandle();

  my $hash = $sh->fetchrow_hashref();

  if($hash) {

    foreach my $lobColumn (@{$tableInfo->{lobColumns}}) {
      my $lobLoc = $hash->{lc($lobColumn)};

      if($lobLoc) {
        my $clobData = $self->readClob($lobLoc);
        $hash->{lc($lobColumn)} = $clobData;
      }
    }
  }
  return $hash;
}


sub connectDatabase {
  my ($self) = @_;

  my $database = $self->getDatabase();

  my $configFile = "$ENV{GUS_HOME}/config/gus.config";

  my $config = GUS::Supported::GusConfig->new($configFile);

  my $login       = $config->getDatabaseLogin();
  my $password    = $config->getDatabasePassword();

  my $dbh = DBI->connect("dbi:Oracle:${database}", $login, $password) or die DBI->errstr;
  $dbh->{RaiseError} = 1;
  $dbh->{AutoCommit} = 0;
  $dbh->{FetchHashKeyName} = "NAME_lc";

  $dbh->do("alter session set nls_date_format = 'yyyy-mm-dd hh24:mi:ss'") or die $dbh->errstr;

  $self->setDatabaseHandle($dbh);
}

sub disconnectDatabase {
  my ($self) = @_;
  my $dbh = $self->getDatabaseHandle();

  $dbh->disconnect();
}

sub getOrListSql {
  my ($self, $field, $list) = @_;
  return join("\n or ", map { /%/ ? "$field like '$_'" : "$field = '$_'" } @$list);
}

sub isRowGlobal {
  my ($self, $row) = @_;

  if(!$self->{_global_row_alg_invocation_ids}) {
    my $dbh = $self->getDatabaseHandle();
    my $listOfGlobalDatasets = $self->getOrListSql('ws.name', \@globalDatasets);
    my $sql = "select w.ALGORITHM_INVOCATION_ID
from APIDB.WORKFLOWSTEPALGINVOCATION w
    ,APIDB.WORKFLOWSTEP ws
where w.workflow_step_id = ws.workflow_step_id
and ( $listOfGlobalDatasets )
UNION
select row_alg_invocation_id from core.algorithm where name = 'SQL*PLUS'
";
## ^ UNION ... not needed for loadRow

    my $sh = $dbh->prepare($sql);
    $sh->execute();

    while( my ($id) = $sh->fetchrow_array()) {
      $self->{_global_row_alg_invocation_ids}->{$id} = 1;
    }
    $sh->finish();
  }

  my $rowAlgInvocationId = $row->{row_alg_invocation_id};

  if($self->{_global_row_alg_invocation_ids}->{$rowAlgInvocationId}) {
    return 1;
  }
  return 0;
}

sub skipRow {
  my ($self, $row) = @_;

  if(!$self->{_skip_row_alg_invocation_ids}) {
    ## Resolve skip/load list
    if($self->{_force_skip_datasets}){
      push(@skipDatasets, @{$self->{_force_skip_datasets}});
    }
    $self->{_skip_row_alg_invocation_ids} = $self->getRowAlgInvocationIds(\@skipDatasets);
  }
  my $rowAlgInvocationId = $row->{row_alg_invocation_id};
  if($self->{_skip_row_alg_invocation_ids}->{$rowAlgInvocationId}) {
    return 1;
  }
  return 0;
}

sub loadRow {
  my ($self, $row) = @_;
  if(! defined($self->{_load_row_alg_invocation_ids})) {
    if($self->{_force_load_datasets}){
      $self->{_load_row_alg_invocation_ids} = $self->getRowAlgInvocationIds($self->{_force_load_datasets});
		}
  }
  my $rowAlgInvocationId = $row->{row_alg_invocation_id};
  if($self->{_load_row_alg_invocation_ids}->{$rowAlgInvocationId}) {
    return 1;
  }
  return 0;
}

sub getRowAlgInvocationIds {
  my ($self, $listOfDatasets) = @_;
  my $datasetList = $self->getOrListSql('ws.name', $listOfDatasets);
  my $dbh = $self->getDatabaseHandle();
      my $sql = "select w.ALGORITHM_INVOCATION_ID
from APIDB.WORKFLOWSTEPALGINVOCATION w
      ,APIDB.WORKFLOWSTEP ws
where w.workflow_step_id = ws.workflow_step_id
and ( $datasetList ) ";
  my $sh = $dbh->prepare($sql);
  $sh->execute();
  my %results;
  while( my ($id) = $sh->fetchrow_array()) {
    $results{$id} = 1;
  }
  $sh->finish();
  return \%results;
}

sub getDistinctTablesForTableIdField {
  my ($self, $field, $table) = @_;

    my $dbh = $self->getDatabaseHandle();

  my $sql = "select distinct nvl(v.name, t.name) as table_name
                           , t.table_id as table_id
                           , nvl(vd.name, d.name) as database_name
from core.tableinfo t
   , core.tableinfo v
   , core.databaseinfo d
   , core.databaseinfo vd
   , $table s
where s.$field = t.table_id
and t.view_on_table_id = v.table_id (+)
and v.database_id = vd.database_id (+)
and d.database_id = t.database_id
";

  my $sh = $dbh->prepare($sql);
  $sh->execute();

  my %rv;

  while(my ($t, $id, $d) = $sh->fetchrow_array()) {
    $rv{$id} = "GUS::Model::${d}::${t}";
  }

  $sh->finish();

  return \%rv;
}



sub getDistinctValuesForField {
  my ($self, $fullTableName, $field) = @_;

  my $tableName = $self->getTableNameFromPackageName($fullTableName);

  my $addRowAlgInvocationId = "";

  my %rv;
  my $dbh = $self->getDatabaseHandle();

  my $sql = "select distinct $field from $tableName";
  my $sh = $dbh->prepare($sql);
  $sh->execute();

  while(my $row = $sh->fetchrow_hashref()) {
    my $value = $row->{lc($field)};

    $rv{$value} = 1;
  }
  $sh->finish();

  return \%rv;
}


sub getMaxFieldLength {
  my ($self, $fullTableName, $field) = @_;

  my $tableName = $self->getTableNameFromPackageName($fullTableName);

  my $dbh = $self->getDatabaseHandle();
  my $sql = "select max(length($field)) from $tableName";

  my $sh = $dbh->prepare($sql);
  $sh->execute();
  my ($length) = $sh->fetchrow_array();
  $sh->finish();

  return $length;
}

sub getTableCount {
  my ($self, $fullTableName, $primaryKeyColumn, $maxPrimaryKey) = @_;

  my $tableName = $self->getTableNameFromPackageName($fullTableName);

  my $dbh = $self->getDatabaseHandle();
  my $sql = "select count(*) from $tableName where $primaryKeyColumn <= $maxPrimaryKey";

  my $sh = $dbh->prepare($sql);
  $sh->execute();
  my ($count) = $sh->fetchrow_array();
  $sh->finish();

  return $count;
}


1;
