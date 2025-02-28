package ApiCommonData::Load::Plugin::InsertGroupDomains;

@ISA = qw(GUS::PluginMgr::Plugin);

# ----------------------------------------------------------------------

use strict;
use GUS::PluginMgr::Plugin;
use FileHandle;

use GUS::Model::ApiDB::OrthomclGroupDomain;

#use ApiCommonData::Load::Util;
use Data::Dumper;

require Exporter;

my $argsDeclaration =
[
 stringArg({ descr => 'OrthoGroup types to edit (P=Peripheral,C=Core,R=Residual)',
	     name  => 'groupTypesCPR',
	     isList    => 0,
	     reqd  => 1,
	     constraintFunc => undef,
	   }),
];


# NOTE:  THIS PLUGIN AND THE TABLE IT LOADS ARE MISNAMED.  Should be "OrthomclGroupDomainKeywords."  (It loads info about keywords, not domains.)

# NOTE: THIS PLUGIN IS FLAWED.  IT IS IGNORING THE KEYWORD FILTERS.

my $purpose = <<PURPOSE;
Calculate the relevant pfam domain keywords for each ortholog group in the DB, 
and insert the domains (with keyword frequencies) into the OrthomclGroupDomain table.
PURPOSE

my $purposeBrief = <<PURPOSE_BRIEF;
Insert the group domain keywords into the OrthomclGroupDomain table  
PURPOSE_BRIEF

my $notes = <<NOTES;
NOTES

my $tablesAffected = <<TABLES_AFFECTED;
ApiDB.OrthomclGroupDomain,
TABLES_AFFECTED

my $tablesDependedOn = <<TABLES_DEPENDED_ON;
ApiDB.OrthologGroup,

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

my @noword=qw(
    ensembl pfam swiss gi
    to of and in the by at with from
    cerevisiae saccharomyces arabidopsis thaliana mus musculus sapiens homo rattus norvegicus gallus plasmodium
    no not
    a the
    some
    contains involved -related related -like like unclassified expressed
    predicted putative ambiguous unknown similar probable possible potential
    family
    identical highly weakly likely nearly
    fragment
);

our @dashword = qw(
    dependent terminal containing specific associated directed rich
    transporting binding reducing conjugating translocating interacting
);

our @nosingleword = qw(
    protein proteins gene genes cds product peptide polypeptide enzyme sequence molecule factor
    function functions subfamily superfamily group profile
    similarity similarities homology homolog conserved 
    type domain domains chain class component components member motif terminal subunit box
    alpha beta delta gamma sigma lambda epsilon
    specific associated
    small
	precursor
);
our @capitalword = qw(
		DNA RNA ATP ADP AMP GTP
		ABC
		ATPase GTPase
		III
		HIV
		UV
		Rab
		NH2
		SH3 SH2 WD LIM PPR
		Na Fe
		CoA
	);

my %word_filter;
foreach (@nosingleword) {$word_filter{nosingleword}->{$_}=1;}
foreach (@capitalword) {$word_filter{capitalword}->{$_}=1;}

# ---------------------------------------------------------------------

sub new {
  my ($class) = @_;
  my $self = {};
  bless($self,$class);

  $self->initialize({ requiredDbVersion => 4,
                      cvsRevision       => '$Revision: 1 $',
                      name              => ref($self),
                      argsDeclaration   => $argsDeclaration,
                      documentation     => $documentation});
 
  return $self;
}

# ======================================================================

sub run {
    my ($self) = @_;

    my $groupTypesCPR = uc($self->getArg('groupTypesCPR'));
    if ( $groupTypesCPR !~ /^[CPRcpr]{1,3}$/ ) {
	die "The orthoGroup type must consist of C, P, and/or R. The value is currently '$groupTypesCPR'\n";
    }
    my %types = map { $_ => 1 } split('',uc($groupTypesCPR));
    my $text = join("','",keys %types);
    $text = "('$text')";

    # read sequence descriptions from db per group
    my $dbh = $self->getQueryHandle();

    my $sql_groups = "SELECT group_id, COUNT(aa_sequence_id)
                      AS num_of_members
                      FROM apidb.orthologgroupaasequence
                      GROUP BY group_id";

    my $ps_groups = $dbh->prepare($sql_groups);
    $ps_groups->execute();
    my %orthIdToNum;
    while (my ($groupId, $numSeqs) = $ps_groups->fetchrow_array()) {
	$orthIdToNum{$groupId} = $numSeqs;
    }

    my $sql_domains_per_group = "SELECT og.group_id, ogs.aa_sequence_id, 
                                        dbref.remark 
                                 FROM apidb.OrthologGroup og,
                                      apidb.OrthologGroupAaSequence ogs, 
                                      dots.DomainFeature df,
                                      dots.DbRefAaFeature dbaf,
                                      sres.DbRef
                                 WHERE ogs.aa_sequence_id = df.aa_sequence_id
                                   AND df.aa_feature_id = dbaf.aa_feature_id
                                   AND dbaf.db_ref_id = dbref.db_ref_id
                                   AND ogs.group_id = og.group_id
                                   AND dbref.remark IS NOT NULL";

    my $ps_domains_per_group = $dbh->prepare($sql_domains_per_group);
    $ps_domains_per_group->execute();
    my %sequenceDomain;
    while (my ($orthId, $seqId, $domain) = $ps_domains_per_group->fetchrow_array()) {
	if (exists $sequenceDomain{$orthId}->{$seqId}->{$domain} ) {
	    $sequenceDomain{$orthId}->{$seqId}->{$domain}++;
	} else {
	    $sequenceDomain{$orthId}->{$seqId}->{$domain} = 1;
	}
    }

    my $groupNum = 0;
    foreach my $group (keys %sequenceDomain) { 
        my $domains = DomainFreq($orthIdToNum{$group}, $sequenceDomain{$group});
        foreach my $d (keys %{$domains}) {
	    my $domain = GUS::Model::ApiDB::OrthomclGroupDomain->new();
	    $domain->setOrthologGroupId($group);
	    $domain->setDescription($d);
	    $domain->setFrequency($domains->{$d});
	    $domain->submit();
	    $self->undefPointerCache();  
	}
        $groupNum++;
        if ($groupNum % 1000 == 0) {
            print STDERR "$groupNum groups processed.\n";
        }
    }

    return "Done adding group domain keywords.";
}

sub undoTables {
    my ($self) = @_;
    
    return ('ApiDB.OrthomclGroupDomain',
	    );
}

# ----------------------------------------------------------------------

sub DomainFreq {
# SELECT sequence2domain.sequence_id, domain_id FROM sequence2domain
#INNER JOIN sequence USING (sequence_id) WHERE sequence.orthogroup_id = ?

# SELECT description FROM domain WHERE domain_id = ?;

    my ($groupSize, $sequenceDomain) = @_;     
    my $maxDomains=3;
    my $minFreq=0.5;
    
    my %domainFrequency;
    foreach my $seq (keys %{$sequenceDomain}) {
	foreach my $domain (keys %{$sequenceDomain->{$seq}}) {
	    if (exists $domainFrequency{$domain}) {
		$domainFrequency{$domain} += $sequenceDomain->{$seq}->{$domain};
	    } else {
		$domainFrequency{$domain} = $sequenceDomain->{$seq}->{$domain};
	    }
	}
    }

    my %finalFreq;
    my $numDomains=0;
    foreach my $d (sort {$domainFrequency{$b}<=>$domainFrequency{$a}} keys %domainFrequency) {
	my $f = $domainFrequency{$d}/$groupSize;
	next unless ($f>$minFreq);
	$numDomains++;
	last if ($numDomains>$maxDomains);
	$finalFreq{$d}=$f;
    }
    return \%finalFreq;
}

1;
