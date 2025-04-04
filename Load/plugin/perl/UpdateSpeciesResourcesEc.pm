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

 stringArg({ descr => 'directory that contains the files downloaded from Veupath sites',
	          name  => 'dataDir',
	          isList    => 0,
	          reqd  => 1,
	          constraintFunc => undef,
	   }),

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

    my $dataDir = $self->getArg('dataDir');

    my $speciesFromOrtho = $self->getSpeciesFromOrtho();
    #my $speciesFromOrtho = $self->updateUniprotData($speciesFromOrtho,$dataDir);
    #my $speciesFromOrtho = $self->updateVeupathData($speciesFromOrtho,$dataDir);
    my $speciesFromOrtho = $self->cleanUpData($speciesFromOrtho);

    my $numRows = $self->loadOrthoResource($speciesFromOrtho);
    $self->log("Finished adding to ApiDB.OrthomclResource. Loaded $numRows rows.\n");

    #$numRows = $self->updateOrthoTaxon($speciesFromOrtho);
    #$self->log("Finished updating ApiDB.OrthomclTaxon. Updated $numRows rows.\n");

    my $ecFileForOrtho = "ecFromVeupath.txt";
    my $ecFileforGenomicSites = "ec_organism.txt";
    my $numEcFiles = $self->formatEcFile($dataDir,$speciesFromOrtho,$ecFileForOrtho,$ecFileforGenomicSites);
    $self->log("Used $numEcFiles EC files obtained from Veupath to make $dataDir/$ecFileForOrtho and $dataDir/$ecFileforGenomicSites\n");
}

sub getSpeciesFromOrtho {
    my ($self) = @_;

    my $sql = <<SQL;
SELECT og.orthomcl_abbrev, og.abbrev, og.taxon_id, tn.name
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
        my $orthomclAbbrev;
        foreach my $abbrev (@abbrevs) {
            if ($species->{$abbrev}->{abbrev} eq $currentFullAbbrev) {
                $orthomclAbbrev = $abbrev;
            }
        }
	$species->{$orthomclAbbrev}->{version} = $row[1];
	$species->{$orthomclAbbrev}->{url} = $row[2];
    }
    
    foreach my $abbrev (keys %{$species}) {
	if (! exists $species->{$abbrev}->{version} ) {
            # Temporarily blocking this out until next run so I can resolve this issue
	    #$self->error("Abbreviation '$abbrev' does not have version in ExtDb or ExtDbRls tables.\n");
	}
	if (! exists $species->{$abbrev}->{url} ) {
            # Temporarily blocking this out until next run so I can resolve this issue
	    #$self->error("Abbreviation '$abbrev' does not have url in ExtDb or ExtDbRls tables.\n");
	}

    }

    return $species;
}

sub updateUniprotData {
    my ($self,$species,$dataDir) = @_;

    my $file = "$dataDir/UniprotProteomes";
    open(IN,$file) || die "Can't open file '$file'\n";
    my $uniprot;
    while (my $line = <IN>) {
	next unless ($line =~ /^UP/);
	chomp $line;
	my @fields = split("\t",$line);
	$uniprot->{$fields[1]}->{proteomeId} = $fields[0];
	$uniprot->{$fields[1]}->{name} = $fields[7];
    }
    close IN;

    foreach my $abbrev (keys %{$species}) {
	next unless (lc($species->{$abbrev}->{url}) =~ /uniprot/);
	$species->{$abbrev}->{resource}="Uniprot";
	my $proteomeId = "";
	$proteomeId = $uniprot->{$species->{$abbrev}->{ncbiTaxId}}->{proteomeId} if (exists $uniprot->{$species->{$abbrev}->{ncbiTaxId}}->{proteomeId});
	my $url = "https://www.uniprot.org/proteomes/".$proteomeId;
	$species->{$abbrev}->{url} = $url;
	$species->{$abbrev}->{name} = $uniprot->{$species->{$abbrev}->{ncbiTaxId}}->{name} if (exists $uniprot->{$species->{$abbrev}->{ncbiTaxId}}->{name});
    }

    return $species;
}

sub updateVeupathData {
    my ($self,$species,$dataDir) = @_;

    my @files = glob("$dataDir/*_organisms.txt");

    my $veupath;
    foreach my $file (@files) {
	open(IN,$file) || die "Can't open file '$file'\n";
	my $resource;
	if ($file =~ /\/([A-Za-z]+)_organisms\.txt/) {
	    $resource = $1;
	} else {
	    die "Did not find project name in file name: $file\n";
	}
	while (my $line = <IN>) {
	    chomp $line;
	    $line =~ s/<i>//g;
	    $line =~ s/<\/i>//g;
	    next if ($line =~ /^Organism/);
	    next unless ($line =~ /^[A-Za-z]/);
	    my @fields = split("\t",$line);
	    my $abbrev = $fields[2];
	    $abbrev = "rhiz" if ($abbrev eq "rirr"); # this is temporary, because rhiz on orthomcl equals rirr on fungidb  
	    $veupath->{$abbrev}->{name} = $fields[0];
	    $veupath->{$abbrev}->{filename} = $fields[1];
	    $veupath->{$abbrev}->{resource} = $resource;
	}
	close IN;	
    }

    foreach my $abbrev (keys %{$species}) {
	next unless (exists $veupath->{$abbrev});
	$species->{$abbrev}->{resource} = $veupath->{$abbrev}->{resource};
	$species->{$abbrev}->{name} = $veupath->{$abbrev}->{name};
	$species->{$abbrev}->{url} = getVeupathUrl($species->{$abbrev}->{resource},$veupath->{$abbrev}->{filename});
    }
    return $species;
}

sub getVeupathUrl {
    my ($resource,$filename) = @_;
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
	vectorbase => "vectorbase.org/vectorbase"
     );
    
    if ( exists $projects{lc($resource)} ) {
	$url .= $projects{lc($resource)}."/app/downloads/Current_Release/$filename/fasta/data/";
    } else {
	$url = "";
    }
    
    return $url;
}

sub cleanUpData {
    my ($self,$species) = @_;

    foreach my $abbrev (keys %{$species}) {
	if ( ! exists $species->{$abbrev}->{resource} ) {
	    my $abbrevWithoutOld = $abbrev;
	    $abbrevWithoutOld =~ s/-old//;
	    if ( exists $species->{$abbrevWithoutOld}->{resource} ) {
		$species->{$abbrev}->{resource} = $species->{$abbrevWithoutOld}->{resource};
		my $url = $species->{$abbrevWithoutOld}->{url};
		if ($url =~ /^(.+\/app\/downloads\/)/) {
		    $species->{$abbrev}->{url} = $1;
		}
		if ($species->{$abbrev}->{name} =~ /.+ (\(old build.+\))$/) {
		    $species->{$abbrev}->{name} = $species->{$abbrevWithoutOld}->{name}." ".$1;
		}
	    } elsif (exists $species->{$abbrev}->{url}) {
		if ( $species->{$abbrev}->{url} =~ /.+\.([A-Za-z]+)\.(org|net)/ ) {
		    my $resource = $1;
		    $resource = "VectorBase" if (lc($resource) eq "vectorbase");
		    $species->{$abbrev}->{resource} = $resource;
		    my $url = getVeupathUrl($resource);
		    if ($url ne "") {  #this a veupath url
			if ( $url =~ /^(.+\/app\/downloads\/)/ ) {
			    $species->{$abbrev}->{url} = $1;
			}
		    }
		} else {
		    $species->{$abbrev}->{resource} = "See URL";
		}
	    } else {
		$species->{$abbrev}->{resource} = "unknown";
		$species->{$abbrev}->{url} = "unknown";
	    }
	} else {
	    if ( ! exists $species->{$abbrev}->{url} ) {
		$species->{$abbrev}->{url} = "See Resource";
	    }
	}
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
	$abbrev = "rhiz" if ($abbrev eq "rirr"); # this is temporary, because rhiz on orthomcl equals rirr on fungidb
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


sub updateOrthoTaxon {
    my ($self,$species) = @_;
    
    my $numRows=0;
    foreach my $abbrev (keys %{$species}) {
	my $taxon = GUS::Model::ApiDB::OrthomclTaxon->
	    new({'orthomcl_taxon_id' => $species->{$abbrev}->{orthomclId}
		});

	$taxon->retrieveFromDB();

	if ($taxon->get('name') ne $species->{$abbrev}->{name}) {
	    $taxon->set('name', $species->{$abbrev}->{name});
	}
	$numRows += $taxon->submit();
	$self->undefPointerCache();
    }

    return $numRows;
}


sub formatEcFile {
    my ($self,$dataDir,$species,$ecFileForOrtho,$ecFileforGenomicSites) = @_;

    my @files = glob("$dataDir/*_ec.txt");
    my $numEcFiles= scalar @files;

    my $currentEc = $self->getCurrentEcNumbers();
    my $ecForGenomic;

    open(ORTHO,">","$dataDir/$ecFileForOrtho") || die "Can't open file '$dataDir/$ecFileForOrtho' for writing\n";

    foreach my $file (@files) {
	open(IN,$file) || die "Can't open file '$file'\n";

	my $abbrev="";
	if ($file =~ /\/([A-Za-z]+)_ec\.txt/) {
	    $abbrev = $1;
	    $abbrev = "rhiz" if ($abbrev eq "rirr"); # this is temporary, because rhiz on orthomcl equals rirr on fungidb
	} else {
	    die "Did not find orthomcl abbrev in file name: $file\n";
	}
	my $organismName = $species->{$abbrev}->{name};
        $organismName =~ s/^\s+//;
	my @words = split(/\s/,$organismName);
	my $genus = "";
	$genus = $words[0];
	die "There is no genus for this organism: '$file' '$abbrev' '$species->{$abbrev}->{name}'" if ($genus eq "");

	my $header = <IN>;
	while (my $line = <IN>) {
	    chomp $line;
	    my @row = split("\t",$line);
	    my ($gene,$tx,$ec,$ecDerived) = ($row[0],$row[1],$row[2],$row[3]);

	    my @multipleEcs = split(/;/,$ec);
	    foreach my $ecStr (@multipleEcs) {
		if ($ecStr =~ /^([0-9\-\.]+)/) {
		    my $singleEc = $1;
		    $ecForGenomic->{$genus}->{$singleEc} = 1;
		    my $tempString = "$abbrev|$gene|$singleEc";
		    next if (exists $currentEc->{$tempString});
		    $currentEc->{$tempString} = 1;
		    print ORTHO "$abbrev|$gene\t$singleEc\n";
		}
	    }

	    @multipleEcs = split(/;/,$ecDerived);
	    foreach my $ecStr (@multipleEcs) {
		if ($ecStr =~ /^([0-9\-\.]+)/) {
		    my $singleEc = $1;
		    $ecForGenomic->{$genus}->{$singleEc} = 1;
		}
	    }
	    
	}
	close IN;
    }
    close ORTHO;

    open(GEN,">","$dataDir/$ecFileforGenomicSites") || die "Can't open file '$dataDir/$ecFileforGenomicSites' for writing\n";
    foreach my $genus (keys %{$ecForGenomic}) {
	foreach my $ec (keys %{$ecForGenomic->{$genus}}) {
	    print GEN "$ec\t$genus\n";
	}
    }   
    close GEN;

    return $numEcFiles;
}

sub getCurrentEcNumbers {
    my ($self) = @_;

    my %ec;

    my $sql = <<SQL;
SELECT eas.secondary_identifier,ec.ec_number
FROM SRes.EnzymeClass ec,
     DoTS.AASequenceEnzymeClass aaec,
     dots.ExternalAASequence eas
WHERE ec.enzyme_class_id = aaec.enzyme_class_id
      AND aaec.aa_sequence_id = eas.aa_sequence_id
SQL

    my $dbh = $self->getQueryHandle();
    my $sth = $dbh->prepareAndExecute($sql);
    while (my @row = $sth->fetchrow_array()) {
	my $tempString = $row[0]."|".$row[1];
	$ec{$tempString} = 1;
    }
    return \%ec;
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
