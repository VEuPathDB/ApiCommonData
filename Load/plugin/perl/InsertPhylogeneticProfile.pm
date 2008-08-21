package ApiCommonData::Load::Plugin::InsertPhylogeneticProfile;

@ISA = qw(GUS::PluginMgr::Plugin);

# ----------------------------------------------------------------------

use strict;
use GUS::PluginMgr::Plugin;
use FileHandle;

use GUS::Model::ApiDB::PhylogeneticProfile;


my $argsDeclaration =
[

    fileArg({name           => 'groupsFile',
            descr          => 'ortholog groups file as found on OrthoMCL-DB download site',
            reqd           => 1,
            mustExist      => 1,
	    format         => 'OG2_1009: osa|ENS1222992 pfa|PF11_0844...',
            constraintFunc => undef,
            isList         => 0, }),

   stringArg({ descr => 'List of taxon abbrevs we want to load (eg: pfa, pvi)',
	     name  => 'taxaToLoad',
	     isList    => 1,
	     reqd  => 1,
	     constraintFunc => undef,
	   }),
];

my $purpose = <<PURPOSE;
Insert rows into ApiDB::PhylogeneticProfile representing the phylogenetic pattern for each of our genes.  Each row maps a source_id (gene) to a long string representing its profile.  We scan all ortholog groups provided on input.  Gather from them the total set of taxa seen in the file, and, for any group that contains any of our genes, associate with each of those genes the list of taxa found in that group.  That is the profile for that gene.

Here is a sample profile string written into the database:
aae:N-aed:Y-aga:Y-ago:Y-ame:Y-aor:Y-ath:Y-atu:N-ban:N-bma:Y-bsu:N-bur:N-cbr:Y-cbu:N-cel:Y-cgl:Y-cho:Y-cin:Y-cje:N-cme:Y-cne:Y-cpa:Y-cpe:N-cpn:N-cre:Y-cte:N-ddi:Y-det:N-dha:Y-dme:Y-dra:N-dre:Y-eco:N-ecu:Y-ehi:Y-fru:Y-ftu:N-gga:Y-gla:Y-gsu:N-gth:N-hal:N-hsa:Y-kla:Y-lma:Y-lmo:N-mja:N-mmu:Y-mtu:N-ncr:Y-neq:N-osa:Y-ota:Y-pbe:Y-pch:Y-pfa:Y-pha:Y-pkn:Y-pvi:Y-pyo:Y-rba:N-rno:Y-rso:N-rty:N-sau:N-sce:Y-sfl:N-sma:N-spn:N-spo:Y-sso:N-sty:N-syn:N-tan:Y-tbr:Y-tcr:Y-tgo:Y-the:Y-tma:N-tni:Y-tpa:N-tps:Y-tth:Y-vch:N-wsu:N-yli:Y-ype:N
PURPOSE

my $purposeBrief = <<PURPOSE_BRIEF;

PURPOSE_BRIEF

my $notes = <<NOTES;

NOTES

my $tablesAffected = <<TABLES_AFFECTED;
ApiDB::PhylogeneticProfile
TABLES_AFFECTED

my $tablesDependedOn = <<TABLES_DEPENDED_ON;
TABLES_DEPENDED_ON

my $howToRestart = <<RESTART;
There are no restart facilities for this plugin
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

  $self->initialize({ requiredDbVersion => 3.5,
                      cvsRevision       => '$Revision$',
                      name              => ref($self),
                      argsDeclaration   => $argsDeclaration,
                      documentation     => $documentation});

  return $self;
}

# ======================================================================

sub run {
  my ($self) = @_;

  # put our taxa into a hash
  my $taxaToLoad = $self->getArg('taxaToLoad');
  my $ourTaxa = {};
  map ($ourTaxa->{$_} = 1) @$taxaToLoad;

  # first pass: go through file, collecting:
  #  - all taxa in file
  #  - all taxa associated with each one of our genes
  open(FILE, $self->getArg('groupsFile')) || die "Could Not open Ortholog File for reading: $!\n";
  my ($counter, $genesProfiles, $allTaxa);
  while(my $line = <FILE>) {
    chomp($line);

    if($counter++ % 1000 == 0) {
      $self->log("Processed $counter lines from groupsFile");
    }

    my ($groupId, $membersString) = split(':', $line);
    my @members = split(" ", $membersString);
    my $taxaInThisGroup = {};
    foreach my $member (@members) {
	# pfa|PF11_0987
	my ($taxonCode, $sourceId) = split("|", $member);
	$taxaInThisGroup->{$taxonCode} = 1;
	$allTaxa->{$taxonCode} = 1;
	$geneProfiles->{$sourceId} = $taxaInThiGroup if $ourTaxa->{$taxonCode};
    }
  }
	
  # second pass: format string needed for database, and insert
  my @allTaxaSorted = sort(keys(%$allTaxa));
  my $count;
  foreach my $sourceId (keys(%$geneProfiles)) {
      my @fullProfile;
      foreach my $taxaCode (@allTaxaSorted) {
	  my $yesNo = $geneProfiles->{$sourceId}->{$taxaCode}? 'Y' : 'N';
	  push(@fullProfile, "$taxaCode:$yesNo");
      }
      my $profileString = join(':', @fullProfile);
      my $profile = GUS::Model::ApiDB::PhylogeneticProfile->
	  new({source_id => $sourceId,
	       profile_string => $profileString
	      });
      $profile->submit();
      
      $count++;
      if($count % 100 == 0) {
	  $self->log("Inserted $count Entries into PhylogeneticProfile");
	  $self->undefPointerCache();
      }
  }

  return("Loaded $count ApiDB::PhylogeneticProfile entries");
}

sub undoTables {
  my ($self) = @_;

  return ('ApiDB.PhylogeneticProfile',
	 );
}

1;
