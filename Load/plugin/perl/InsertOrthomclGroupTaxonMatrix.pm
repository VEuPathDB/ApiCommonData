package ApiCommonData::Load::Plugin::InsertOrthomclGroupTaxonMatrix;

@ISA = qw(GUS::PluginMgr::Plugin);

# ----------------------------------------------------------------------

use strict;
use GUS::PluginMgr::Plugin;
use FileHandle;
use Data::Dumper;

my $argsDeclaration =
[

];

my $purpose = <<PURPOSE;
Calculate number of proteins and number of taxa per orthogroup per species, including for each clade. This creates a new table for this: ApiDB.OrthologGroupTaxon
PURPOSE

my $purposeBrief = <<PURPOSE_BRIEF;
Creates a new table: ApiDB.OrthologGroupTaxon, which houses number of proteins and taxa per orthogroup
PURPOSE_BRIEF

my $notes = <<NOTES;

NOTES

my $tablesAffected = <<TABLES_AFFECTED;
ApiDB.OrthologGroupTaxon
TABLES_AFFECTED

my $tablesDependedOn = <<TABLES_DEPENDED_ON;
ApiDB.OrthomclTaxon, ApiDB.OrthologGroup, ApiDB.OrthologGroupAaSequence, Dots.ExternalAaSequence, Dots.AaSequence
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


# note: in this code, "taxa" or "taxon" refers to both species and clades.
sub run {
    my ($self) = @_;

    my $dbh = $self->getDbHandle();

    $self->log("creating table apidb.orthologgrouptaxon with number of proteins per species per orthologgroup");
    my $numSpeciesRows = $self->createTable($dbh);
    $self->log("created table with $numSpeciesRows rows");

    $self->log("getting species per clade per orthogroup");
    my $speciesToClades = $self->getSpeciesToClades($dbh);
    $self->log("adding rows per clade per orthogroup");
    my $numCladeRows = $self->addCladeRows($dbh,$speciesToClades);
    $self->log("added $numCladeRows rows");

}


sub createTable {
    my ($self, $dbh) = @_;

    my $sql = <<EOF;
CREATE TABLE apidb.orthologgrouptaxon (
    three_letter_abbrev VARCHAR(5),
    number_of_proteins VARCHAR(40),
    number_of_taxa VARCHAR(40),
    group_id VARCHAR(40),
    modification_date TIMESTAMP,
    PRIMARY KEY (three_letter_abbrev, number_of_proteins, number_of_taxa, group_id)
    );

INSERT INTO apidb.orthologgrouptaxon (three_letter_abbrev, number_of_proteins, number_of_taxa, group_id, modification_date)
SELECT org.orthomcl_abbrev AS three_letter_abbrev,
       COUNT(ogas.aa_sequence_id) AS number_of_proteins,
       1 AS number_of_taxa, 
       og.group_id, 
       CURRENT_TIMESTAMP AS modification_date
FROM apidb.orthologgroup og
JOIN apidb.orthologgroupaasequence ogas ON ogas.group_id = og.group_id
JOIN dots.aasequence das ON das.aa_sequence_id = ogas.aa_sequence_id
JOIN apidb.organism org ON org.taxon_id = das.taxon_id
GROUP BY org.orthomcl_abbrev, og.group_id
EOF

    $dbh->prepareAndExecute($sql);
    $dbh->commit();
    $self->undefPointerCache();

    $self->log("Table apidb.orthologgrouptaxon created.");

    my $cladeSql = <<EOF;
INSERT INTO apidb.orthologgrouptaxon (three_letter_abbrev, number_of_proteins, number_of_taxa, group_id, modification_date)
SELECT three_letter_abbrev AS three_letter_abbrev, 
CURRENT_TIMESTAMP AS modification_date, 
0 AS number_of_proteins,
1 AS number_of_taxa,
NULL AS group_id
FROM apidb.orthomclclade
WHERE core_peripheral = 'Z'
EOF

    $self->log("Adding clade rows to apidb.orthologgrouptaxon.");

    $dbh->prepareAndExecute($cladeSql);
    $dbh->commit();
    $self->undefPointerCache();

    $sql = "grant select on apidb.orthologgrouptaxon to gus_r";
    $dbh->prepareAndExecute($sql);
    $dbh->commit();
    $self->undefPointerCache();

    $self->log("Added clade rows to apidb.orthologgrouptaxon.");

    $sql = "grant insert, select, update, delete on apidb.orthologgrouptaxon to gus_w";
    $dbh->prepareAndExecute($sql);
    $dbh->commit();
    $self->undefPointerCache();

    $sql = "SELECT count(*) from apidb.orthologgrouptaxon";
    my $stmt = $dbh->prepareAndExecute($sql);
    my @row = $stmt->fetchrow_array();
    return $row[0];
}

sub getSpeciesToClades {
    my ($self,$dbh) = @_;

    my %tree;
    my %clades;
    my %species;

    my $sql = <<EOF;
SELECT org.taxon_id, st.parent_id, org.orthomcl_abbrev, org.core_peripheral
FROM apidb.organism org, sres.taxon st
WHERE org.taxon_id = st.taxon_id
EOF

    my $stmt = $dbh->prepareAndExecute($sql);
    $self->log("Starting to get species to clades");
    while ( my ($id, $parent, $name, $type) = $stmt->fetchrow_array() ) {
	$tree{$id}=$parent if ($parent);
        $species{$id}=$name;
    }
    $self->undefPointerCache();

    my $cladeSql = <<EOF;
SELECT orthomcl_clade_id, parent_id, three_letter_abbrev, core_peripheral
FROM apidb.orthomclclade
WHERE core_peripheral = 'Z'
EOF

    my $cladeStmt = $dbh->prepareAndExecute($cladeSql);
    while ( my ($id, $parent, $name, $type) = $cladeStmt->fetchrow_array() ) {
        $clades{$id}=$name;
    }
    $self->undefPointerCache();

    $self->log("processing species to clades");
    my $speciesToClades;
    foreach my $speciesId (keys %species) {
	my $parents=[];
        
	getParents($parents,$speciesId,\%tree);
	my @parentNames = map { $clades{$_} } @{$parents};
	$speciesToClades->{$species{$speciesId}} = [];
	push $speciesToClades->{$species{$speciesId}}, @parentNames;
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

sub addCladeRows {
    my ($self, $dbh, $speciesToClades) = @_;

    my $clades;
    my $sql = <<EOF;
SELECT three_letter_abbrev,number_of_proteins,number_of_taxa,group_id
FROM apidb.orthologgrouptaxon
EOF

    my $stmt = $dbh->prepareAndExecute($sql);
    while (my ($name, $numProteins, $numTaxa, $orthoId) = $stmt->fetchrow_array()) {
	foreach my $clade (@{$speciesToClades->{$name}}) {
	    $clades->{$clade}->{$orthoId}->{numTaxa} += $numTaxa;
	    $clades->{$clade}->{$orthoId}->{numProteins} += $numProteins;
	}
    }
    $self->undefPointerCache();

    my $numCladeRows = 0;
    $sql = <<EOF;
INSERT INTO apidb.orthologgrouptaxon (three_letter_abbrev,number_of_proteins,number_of_taxa,group_id,modification_date)
VALUES (?,?,?,?,CURRENT_TIMESTAMP)
EOF
    $stmt = $dbh->prepare($sql);
    foreach my $clade (keys %{$clades}) {
	foreach my $orthoId (keys %{$clades->{$clade}}) {
	    my $numProteins = $clades->{$clade}->{$orthoId}->{numProteins};
	    my $numTaxa = $clades->{$clade}->{$orthoId}->{numTaxa};
	    $stmt->execute($clade,$numProteins,$numTaxa,$orthoId);
	    $dbh->commit();
            $self->undefPointerCache();
	    $numCladeRows++;
	}
    }

    return $numCladeRows;
}

# ----------------------------------------------------------------


sub undoTables {
  my ($self) = @_;

  return ( );
}


sub undoPreprocess {
    my ($self, $dbh, $rowAlgInvocationList) = @_;

    my $sql = "DROP TABLE ApiDB.OrthologGroupTaxon";

    print STDERR "executing sql: $sql\n";
    my $queryHandle = $dbh->prepare($sql) or die $dbh->errstr;
    $queryHandle->execute() or die $dbh->errstr;

}


1;
