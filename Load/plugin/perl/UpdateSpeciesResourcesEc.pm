package ApiCommonData::Load::Plugin::UpdateSpeciesResourcesEc;

@ISA = qw(GUS::PluginMgr::Plugin);

# ----------------------------------------------------------------------

use strict;
use GUS::PluginMgr::Plugin;
use GUS::Model::ApiDB::OrthomclResource;
use GUS::Model::ApiDB::Organism;
use FileHandle;
use Data::Dumper;

my $argsDeclaration =
[

];


my $purpose = <<PURPOSE;
Insert proteome source, format Ec file, and update organism name, all obtained from VEuPathDB sites.
PURPOSE

my $purposeBrief = <<PURPOSE_BRIEF;
Insert proteome source, format Ec file, and update organism name, all obtained from VEuPathDB sites.
PURPOSE_BRIEF

my $notes = <<NOTES;

NOTES

my $tablesAffected = <<TABLES_AFFECTED;
ApiDB.OrthomclResource,
ApiDB.Organism
TABLES_AFFECTED

my $tablesDependedOn = <<TABLES_DEPENDED_ON;
ApiDB.Organism,
Sres.ExternalDatabase,
Sres.ExternalDatabaseRelease,
Sres.TaxonName
TABLES_DEPENDED_ON

my $howToRestart = <<RESTART;
Use the Undo plugin first.
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

sub run {
    my ($self) = @_;

    my $speciesFromOrtho = $self->getSpeciesFromOrtho();
    my $speciesFromOrtho = $self->addUrlAndResource($speciesFromOrtho);

    my $numRows = $self->loadOrthoResource($speciesFromOrtho);
    $self->log("Finished adding to ApiDB.OrthomclResource. Loaded $numRows rows.\n");
}

sub getSpeciesFromOrtho {
    my ($self) = @_;

    my $sql = <<SQL;
SELECT og.orthomcl_abbrev, og.abbrev, og.taxon_id, tn.name, og.project_name, og.genome_source, og.name_for_filenames
FROM apidb.organism og, sres.taxonname tn
WHERE og.core_peripheral IN ('core','peripheral')
AND og.taxon_id = tn.taxon_id
AND tn.name_class = 'scientific name';
SQL
 
    my $dbh = $self->getQueryHandle();
    my $sth = $dbh->prepareAndExecute($sql);

    my $species;
    while (my @row = $sth->fetchrow_array()) {
        $self->log("abbrev is $row[0]\n");
	$species->{$row[0]}->{abbrev} = $row[1];
	$species->{$row[0]}->{orthomclId} = $row[2];
	$species->{$row[0]}->{name} = $row[3];
	$species->{$row[0]}->{project} = $row[4];
	$species->{$row[0]}->{genome_source} = $row[5];
	$species->{$row[0]}->{filename} = $row[6];
    }

    $sql = <<SQL;
SELECT ed.name, edr.version, edr.id_url
FROM Sres.ExternalDatabase ed,
     Sres.ExternalDatabaseRelease edr
WHERE (ed.name like '%_orthomclProteome_RSRC'
          OR ed.name like '%_orthomclPeripheral%'
          OR ed.name like '%_PeripheralFrom%'
          OR ed.name like '%PeripheralFrom%'
          OR ed.name like '%primary_genome_RSRC%')
      AND ed.external_database_id = edr.external_database_id
SQL
 
    $sth = $dbh->prepareAndExecute($sql);

    while (my @row = $sth->fetchrow_array()) {
	my @array = split(/_/, $row[0]);
	my $currentFullAbbrev = shift @array;
        my @abbrevs = keys %$species;
        foreach my $abbrev (@abbrevs) {
            # Example causing issue (abbrev has underscore as part of name
            # ncerPA08_1199_primary_genome_RSRC | 2015-05-05 |
            # orthomcl_abbrev |    abbrev     | taxon_id |              name                
            #-----------------+---------------+----------+---------------------------------
            # ncep            | ncerPA08_1199 |  2658573 | Nosema ceranae strain PA08_1199
	    my @abbrevArray = split(/_/, $species->{$abbrev}->{abbrev});
	    my $abbrevBeforeUnderscore = shift @abbrevArray;
            if ($abbrevBeforeUnderscore eq $currentFullAbbrev) {
            	$species->{$abbrev}->{version} = $row[1];
            }
        }
    }
    
    foreach my $abbrev (keys %{$species}) {
	if (! exists $species->{$abbrev}->{version} ) {
	    $self->error("Abbreviation '$abbrev' does not have version in ExtDb or ExtDbRls tables.\n");
	}
    }
    return $species;
}


sub getUrl {
    my ($self,$project,$filename) = @_;
    my $url = "https://";

    my %projects = (
        microsporidiadb => "microsporidiadb.org/micro",
        toxodb => "toxodb.org/toxo",
        amoebadb => "amoebadb.org/amoeba",
        cryptodb => "cryptodb.org/cryptodb",
        fungidb => "fungidb.org/fungidb",
        giardiadb => "giardiadb.org/giardiadb",
	piroplasmadb => "piroplasmadb.org/piro",
	plasmodb => "plasmodb.org/plasmo",
	trichdb => "trichdb.org/trichdb",
	tritrypdb => "tritrypdb.org/tritrypdb",
	hostdb => "hostdb.org/hostdb",
	schistodb => "schistodb.net/schisto",
	vectorbase => "vectorbase.org/vectorbase",
	orthomcl => "vectorbase.org/vectorbase"
     );
    
    if ( exists $projects{lc($project)} ) {
        if ($project eq 'OrthoMCL') {
            $url .= 'www.uniprot.org/uniprot/EXTERNAL_ID_HERE';
        }
        else {
	    $url .= $projects{lc($project)}."/app/downloads/Current_Release/${filename}/fasta/data/";
        }
    } else {
        $self->error("No project for filename $filename\n");
    }
    return $url;
}

sub addUrlAndResource {
    my ($self,$species) = @_;

    foreach my $abbrev (keys %{$species}) {
        my $project = $species->{$abbrev}->{project};
        my $fileName = $species->{$abbrev}->{fileName};
        my $url = $self->getUrl($project,$fileName);
        $species->{$abbrev}->{url} = $url;
        $species->{$abbrev}->{resource} = $project;
    }
    return $species;
}

sub loadOrthoResource {
    my ($self, $species) = @_;

    my $sql = "SELECT orthomcl_taxon_id FROM apidb.orthomclresource";
    my $dbh = $self->getQueryHandle();
    my $sth = $dbh->prepareAndExecute($sql);
    my $numPast=0;
    while (my @row = $sth->fetchrow_array()) {
	$numPast++;
    }
    if ( $numPast > 0) {
	$self->log("There are $numPast rows in ApiDB.OrthomclResource. This table should be empty.\n");
    }

    my $numRows=0;
    foreach my $abbrev (keys %{$species}) {
	my $id = $species->{$abbrev}->{orthomclId};
	if (! $id) {
	    die "organism does not have an orthomcl_taxon_id:\nabbrev '$abbrev'\n";
	    next;
	}
	my $resource = defined $species->{$abbrev}->{resource} ? $species->{$abbrev}->{resource} : "-"; 
	my $url = defined $species->{$abbrev}->{url} ? $species->{$abbrev}->{url} : "-";
	my $version = defined $species->{$abbrev}->{version} ? $species->{$abbrev}->{version} : "-";
	my $name = defined $species->{$abbrev}->{name} ? defined $species->{$abbrev}->{name} : "-";
	my $res = GUS::Model::ApiDB::OrthomclResource->new({'orthomcl_taxon_id'=>$id});
	$res->set('resource_name', $resource);
	$res->set('resource_url', $url);
	$res->set('resource_version', $version);
	$numRows += $res->submit();
	$res->undefPointerCache();
    }
    
    return $numRows;
}

sub undoTables {
    my ($self) = @_;

    return (
	    );
}


sub undoPreprocess {
    my ($self, $dbh, $rowAlgInvocationList) = @_;
    my $rowAlgInvocations = join(',', @{$rowAlgInvocationList});

    my $sql = "TRUNCATE TABLE ApiDB.OrthomclResource";
    my $sh = $dbh->prepare($sql);
    $sh->execute();
    $sh->finish();
}

1;
