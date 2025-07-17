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
            descr          => 'ortholog groups file as produced by orthofinder',
            reqd           => 1,
            mustExist      => 1,
	    format         => 'OG7_0001009: osa|ENS1222992 pfa|PF11_0844...',
            constraintFunc => undef,
            isList         => 0, }),

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

  $self->initialize({ requiredDbVersion => 4.0,
                      cvsRevision       => '$Revision$',
                      name              => ref($self),
                      argsDeclaration   => $argsDeclaration,
                      documentation     => $documentation});

  return $self;
}

# ======================================================================

sub run {
  my ($self) = @_;

  my %allTaxa;

  my $sql = "select orthomcl_abbrev from ApiDB.Organism";
  my $sth = $self->prepareAndExecute($sql);

  while (my ($orthomclAbbrev) = $sth->fetchrow_array()) {
      $allTaxa{$orthomclAbbrev} = 1;
  }

  my @allTaxaSorted = sort(keys(%allTaxa));

  open(FILE, $self->getArg('groupsFile')) || die "Could Not open Ortholog File for reading: $!\n";

  my ($counter);
  while (my $line = <FILE>) {
    chomp($line);
    my ($groupId, $membersString) = split(/\:\s/, $line);
    my @members = split(/\s/, $membersString);

    my %taxaInThisGroup;

    foreach my $member (@members) {
      # pfal|PF11_0987
      my ($taxonCode, $sourceId) = split(/\|/, $member);
      $taxaInThisGroup{$taxonCode} = 1;
    }

    my @fullProfile;

    foreach my $taxaCode (@allTaxaSorted) {
      my $yesNo = $taxaInThisGroup{$taxaCode} ? 'Y' : 'N';
      push(@fullProfile, "$taxaCode:$yesNo");
    }

    my $profileString = join(':', @fullProfile);

    my $profile = GUS::Model::ApiDB::PhylogeneticProfile->new({source_id => $groupId, profile_string => $profileString});
    $profile->submit();

    $counter++;
    if ($counter % 10000 == 0) {
      $self->log("Processed $counter lines from groupsFile");
      $self->undefPointerCache();
    }

  }
}

sub undoTables {
  my ($self) = @_;
  return ('ApiDB.PhylogeneticProfile');
}

1;
