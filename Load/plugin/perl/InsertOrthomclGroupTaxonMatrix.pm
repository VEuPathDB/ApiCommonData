package ApiCommonData::Load::Plugin::InsertOrthomclGroupTaxonMatrix;
use lib "$ENV{GUS_HOME}/lib/perl";

@ISA = qw(GUS::PluginMgr::Plugin);

# ----------------------------------------------------------------------

use strict;
use GUS::PluginMgr::Plugin;
use GUS::Model::ApiDB::OrthologGroupTaxon;
use FileHandle;
use File::Temp qw/ tempdir /;
use POSIX qw/ strftime /;
use Data::Dumper;

use ApiCommonData::Load::Psql;
use ApiCommonData::Load::Fifo;

my $argsDeclaration =
[

];

my $purpose = <<PURPOSE;
Calculate number of proteins and number of taxa per orthogroup per species, including for each clade, and load them into ApiDB.OrthologGroupTaxon.
PURPOSE

my $purposeBrief = <<PURPOSE_BRIEF;
Populates ApiDB.OrthologGroupTaxon, which houses number of proteins and taxa per orthogroup
PURPOSE_BRIEF

my $notes = <<NOTES;

NOTES

my $tablesAffected = <<TABLES_AFFECTED;
ApiDB.OrthologGroupTaxon
TABLES_AFFECTED

my $tablesDependedOn = <<TABLES_DEPENDED_ON;
ApiDB.OrthomclClade, ApiDB.OrthologGroup, ApiDB.OrthologGroupAaSequence, ApiDB.Organism, Dots.AaSequence
TABLES_DEPENDED_ON

my $howToRestart = <<RESTART;
Use the Undo plugin.
RESTART

my $failureCases = <<FAIL_CASES;

FAIL_CASES

my $documentation = { purpose          => $purpose,
                      purposeBrief     => $purposeBrief,
                      notes            => $notes,
                      tablesAffected   => $tablesAffected,
                      tablesDependedOn => $tablesDependedOn,
                      howToRestart     => $howToRestart,
                      failureCases     => $failureCases };

# ----------------------------------------------------------------------

sub new {
  my ($class) = @_;
  my $self = {};
  bless($self,$class);

  $self->initialize({ requiredDbVersion => 4,
                      cvsRevision       => '$Revision$',
                      name              => ref($self),
                      argsDeclaration   => $argsDeclaration,
                      documentation     => $documentation});

  return $self;
}

# ======================================================================

my $TABLE_NAME = "apidb.orthologgrouptaxon";
my $SEQUENCE_NAME = "apidb.orthologgrouptaxon_sq";

# note: in this code, "taxa" or "taxon" refers to both species and clades.
sub run {
    my ($self) = @_;

    my $dbh = $self->getDbHandle();

    $self->log("inserting rows into $TABLE_NAME with number of proteins per species per orthologgroup");
    my $numSpeciesRows = $self->insertSpeciesRows($dbh);
    $self->log("inserted $numSpeciesRows rows");

    $self->log("getting species per clade per orthogroup");
    my $speciesToClades = $self->getSpeciesToClades($dbh);

    $self->log("adding rows per clade per orthogroup");
    my $numCladeRows = $self->addCladeRows($dbh,$speciesToClades);
    $self->log("added $numCladeRows rows");
}


sub insertSpeciesRows {
    my ($self, $dbh) = @_;

    my $audit = $self->getAuditDefaults();

    my $sql = <<EOF;
INSERT INTO $TABLE_NAME
       (ortholog_group_taxon_id, three_letter_abbrev, number_of_proteins, number_of_taxa,
        group_id, modification_date,
        user_read, user_write, group_read, group_write, other_read, other_write,
        row_user_id, row_group_id, row_project_id, row_alg_invocation_id)
SELECT nextval('$SEQUENCE_NAME'),
       org.orthomcl_abbrev AS three_letter_abbrev,
       COUNT(ogas.aa_sequence_id) AS number_of_proteins,
       1 AS number_of_taxa,
       og.group_id,
       CURRENT_TIMESTAMP,
       $audit->{user_read}, $audit->{user_write}, $audit->{group_read}, $audit->{group_write},
       $audit->{other_read}, $audit->{other_write},
       $audit->{row_user_id}, $audit->{row_group_id}, $audit->{row_project_id}, $audit->{row_alg_invocation_id}
FROM apidb.orthologgroup og
JOIN apidb.orthologgroupaasequence ogas ON ogas.group_id = og.group_id
JOIN dots.aasequence das ON das.aa_sequence_id = ogas.aa_sequence_id
JOIN apidb.organism org ON org.taxon_id = das.taxon_id
GROUP BY org.orthomcl_abbrev, og.group_id
EOF

    $dbh->prepareAndExecute($sql);
    $dbh->commit();
    $self->undefPointerCache();

    $self->log("Inserted per-species rows into $TABLE_NAME.");

    my $sql2 = "SELECT count(*) from $TABLE_NAME";
    my $stmt = $dbh->prepareAndExecute($sql2);
    my @row = $stmt->fetchrow_array();
    return $row[0];
}

sub getSpeciesToClades {
    my ($self,$dbh) = @_;

    my %tree;
    my %abbrevs;
    my %species;

    # Walk apidb.orthomclclade's own parent_id hierarchy (species and clades
    # share the same orthomcl_clade_id key space in this table), rather than
    # mixing in sres.taxon, whose taxon_ids are an unrelated numbering scheme.
    my $sql = <<EOF;
SELECT orthomcl_clade_id, parent_id, three_letter_abbrev, is_species
FROM apidb.orthomclclade
EOF

    my $stmt = $dbh->prepareAndExecute($sql);
    $self->log("Starting to get species to clades");
    while ( my ($id, $parent, $abbrev, $isSpecies) = $stmt->fetchrow_array() ) {
	$tree{$id}=$parent if (defined $parent);
        $abbrevs{$id}=$abbrev;
        $species{$id}=$abbrev if ($isSpecies);
    }
    $self->undefPointerCache();

    $self->log("processing species to clades");
    my $speciesToClades;
    foreach my $speciesId (keys %species) {
	my $parents=[];

	getParents($parents,$speciesId,\%tree);
	my @parentNames = map { $abbrevs{$_} } @{$parents};
	$speciesToClades->{$species{$speciesId}} = [ @parentNames ];
    }
    $self->log("Got Parents");

    return $speciesToClades;
}

sub getParents {
    my ($parents, $speciesId, $tree) = @_;
    if (exists $tree->{$speciesId}) {
	push @{$parents}, $tree->{$speciesId};
	getParents($parents, $tree->{$speciesId}, $tree);
    }
}

# Sum number_of_proteins/number_of_taxa for every ancestor clade of each
# species row already loaded into apidb.orthologgrouptaxon.
sub computeCladeTotals {
    my ($self, $dbh, $speciesToClades) = @_;

    my $clades = {};
    my $sql = <<EOF;
SELECT three_letter_abbrev,number_of_proteins,number_of_taxa,group_id
FROM $TABLE_NAME
EOF

    my $stmt = $dbh->prepareAndExecute($sql);
    while (my ($name, $numProteins, $numTaxa, $orthoId) = $stmt->fetchrow_array()) {
	foreach my $clade (@{$speciesToClades->{$name}}) {
	    $clades->{$clade}->{$orthoId}->{numTaxa} += $numTaxa;
	    $clades->{$clade}->{$orthoId}->{numProteins} += $numProteins;
	}
    }
    $self->undefPointerCache();

    return $clades;
}

sub addCladeRows {
    my ($self, $dbh, $speciesToClades) = @_;

    my $clades = $self->computeCladeTotals($dbh, $speciesToClades);

    my @rows;
    foreach my $clade (keys %{$clades}) {
	foreach my $orthoId (keys %{$clades->{$clade}}) {
	    push @rows, [$clade, $orthoId,
			 $clades->{$clade}->{$orthoId}->{numProteins},
			 $clades->{$clade}->{$orthoId}->{numTaxa}];
	}
    }

    my $numCladeRows = scalar(@rows);
    return 0 unless $numCladeRows;

    my $primaryKeys = $self->reserveSequenceIds($dbh, $SEQUENCE_NAME, $numCladeRows);
    my $audit = $self->getAuditDefaults();
    my $modificationDate = strftime("%Y-%m-%d %H:%M:%S", localtime());

    my $tmpDir = tempdir(CLEANUP => 1);
    my $fifoName = "$tmpDir/orthologGroupTaxonClades.csv";
    my $fifo = ApiCommonData::Load::Fifo->new($fifoName);

    my $ogtTable = GUS::Model::ApiDB::OrthologGroupTaxon_Table->new();
    my $psqlObj = $self->makePsqlObj($TABLE_NAME, $fifoName, $ogtTable->getAttributeList());
    my $psqlProcessString = $psqlObj->getCommandLine();

    my $pid = $fifo->attachReader($psqlProcessString);
    $self->addActiveForkedProcess($pid);

    my $fh = $fifo->attachWriter();

    my $fields = $psqlObj->getFields();
    foreach my $row (@rows) {
	my ($clade, $orthoId, $numProteins, $numTaxa) = @$row;

	my $valuesHash = { ortholog_group_taxon_id => shift(@$primaryKeys),
			   three_letter_abbrev     => $clade,
			   number_of_proteins      => $numProteins,
			   number_of_taxa          => $numTaxa,
			   group_id                => $orthoId,
			   modification_date       => $modificationDate,
			   %$audit,
	};

	my @values = map { defined($valuesHash->{$_}) ? $valuesHash->{$_} : '' } @$fields;
	print $fh join(",", @values) . "\n";
    }

    $fifo->cleanup();

    return $numCladeRows;
}

sub reserveSequenceIds {
    my ($self, $dbh, $sequenceName, $count) = @_;

    my $sql = "SELECT nextval(?) FROM generate_series(1,?)";
    my $stmt = $dbh->prepare($sql);
    $stmt->execute($sequenceName, $count);

    my @ids;
    while (my ($id) = $stmt->fetchrow_array()) {
	push @ids, $id;
    }
    $self->undefPointerCache();

    return \@ids;
}

sub getAuditDefaults {
    my ($self) = @_;

    my $dbiDb = $self->getDb();

    return { row_user_id           => $dbiDb->getDefaultUserId(),
	     row_group_id          => $dbiDb->getDefaultGroupId(),
	     row_project_id        => $dbiDb->getDefaultProjectId(),
	     row_alg_invocation_id => $dbiDb->getDefaultAlgoInvoId(),
	     user_read             => $dbiDb->getDefaultUserRead(),
	     user_write            => $dbiDb->getDefaultUserWrite(),
	     group_read            => $dbiDb->getDefaultGroupRead(),
	     group_write           => $dbiDb->getDefaultGroupWrite(),
	     other_read            => $dbiDb->getDefaultOtherRead(),
	     other_write           => $dbiDb->getDefaultOtherWrite(),
    };
}

sub makePsqlObj {
  my ($self, $tableName, $fifo, $attributeList) = @_;

  my $dbiDsn = $self->getDb->getDSN();
  $dbiDsn =~ /(:|;)dbname=((\w|\.)+);?/ ;
  my $db = $2;

  $dbiDsn =~ /(:|;)host=((\w|\.)+);?/ ;
  my $hostName = $2;

  my $psqlObj = ApiCommonData::Load::Psql->new({
    _login => $self->getDb->getLogin(),
    _password => $self->getDb->getPassword(),
    _database => $db,
    _hostName=> $hostName,
    _quiet => 0,
  });

  $psqlObj->setInfileName($fifo);
  $psqlObj->setTableName($tableName);
  $psqlObj->setFieldDelimiter(",");

  my @dataFields = map { lc($_) } @$attributeList;

  $psqlObj->setFields(\@dataFields);

  return $psqlObj;
}

# ----------------------------------------------------------------

sub error {
  my ($self, $msg) = @_;
  print STDERR "\nERROR: $msg\n";

  foreach my $pid (@{$self->getActiveForkedProcesses()}) {
    kill(9, $pid);
  }

  $self->SUPER::error($msg);
}

sub getActiveForkedProcesses {
  my ($self) = @_;

  return $self->{_active_forked_processes} || [];
}

sub addActiveForkedProcess {
  my ($self, $pid) = @_;

  push @{$self->{_active_forked_processes}}, $pid;
}

# ----------------------------------------------------------------


sub undoTables {
  my ($self) = @_;

  return ('ApiDB.OrthologGroupTaxon');
}


sub undoPreprocess {
    my ($self, $dbh, $rowAlgInvocationList) = @_;

    $dbh->do("truncate table $TABLE_NAME");
}


1;
