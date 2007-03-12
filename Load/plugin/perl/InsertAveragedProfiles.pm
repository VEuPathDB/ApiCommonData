package ApiCommonData::Load::Plugin::InsertAveragedProfiles;

@ISA = qw(GUS::PluginMgr::Plugin);

use strict;
use GUS::PluginMgr::Plugin;
use GUS::Model::PlasmoDB::Profile;
use GUS::Model::PlasmoDB::ProfileSet;
use GUS::Model::PlasmoDB::ProfileElement;
use GUS::Model::PlasmoDB::ProfileElementName;
use ApiCommonData::Load::ExpressionProfileInsertion;

my $argsDeclaration =
[
   stringArg({name           => 'profileSetNames',
	      descr          => 'Names of ProfileSets to average',
	      reqd           => 1,
	      constraintFunc => undef,
	      isList         => 1, }),
 
   stringArg({name => 'externalDatabaseSpec',
	      descr => 'External database of the profile sets (name|version format)',
	      constraintFunc=> undef,
	      reqd  => 1,
	      isList => 0
	     }),

 	 booleanArg ({name => 'loadProfileElement',
	              descr => 'Set this to load the ProfileElement table with the individual profile elements',
	              reqd => 0,
                      default =>0
                     }),
 
];

my $purpose = <<PURPOSE;
Insert profiles for genes computed by averaging profiles for the oligos that map to the genes.  Adds the new profiles to the same external database release as the oligo profiles.  For each profile set provided, creates a new profile set to contain the averaged profiles for the input profile set.
PURPOSE

my $purposeBrief = <<PURPOSE_BRIEF;
Insert profiles for genes computed by averaging profiles for the oligos that map to the genes.
PURPOSE_BRIEF

my $notes = <<NOTES;
NOTES

my $tablesAffected = <<TABLES_AFFECTED;
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

sub run {
  my ($self) = @_;

  my $profileSetNames = $self->getArg('profileSetNames');

  my $extDbRlsId = $self->getExtDbRlsId($self->getArg('externalDatabaseSpec'));

  my @done;
  foreach my $profileSetName (@{$profileSetNames}) {
    my $count = $self->processProfileSet($profileSetName, $extDbRlsId);
    push(@done, "$profileSetName Averaged, ($count genes)");
  }
  return "Inserted " . join(";  ", @done);

}

sub processProfileSet {
  my ($self, $profileSetName, $extDbRlsId) = @_;

  $self->log("Creating averaged ProfileSet for $profileSetName");

  my $gene2profileIds = 
    $self->findGene2ProfilesMapping($profileSetName, $extDbRlsId); #debug sql

  my ($descrip, $header) = $self->getMetaInfo($profileSetName, $extDbRlsId);
  my $expectedElementCount =  scalar($header);

  my @genes = keys(%{$gene2profileIds});

  $self->log("Generating averaged profiles for ". scalar(@genes) ." genes");
  my $count = 0;
  my $profileRows = [];
  foreach my $gene (@genes) {
    my @averageProfile = $self->getAverageProfile($gene2profileIds->{$gene},
						  $expectedElementCount);

    next if scalar(@averageProfile) == 0; # a dud

    if (scalar @averageProfile != $expectedElementCount) {
      die "GeneId $gene has ".scalar(@averageProfile)." averaged timepoints but we expected $expectedElementCount";
    }

    my $row = [$gene, @averageProfile];
    push (@$profileRows, $row);
    $count++;
  }

  $self->log("Created profile set with $count genes (the rest being duds)");

  &processInputProfileSet($self, $extDbRlsId, $header, $profileRows,
			  "$profileSetName Averaged", $descrip,
			  'gene', $self->getArg('loadProfileElement'),
			  0, 0);

  return $count;
}


# return a hash with geneID as key, and list of profileIds as value
sub findGene2ProfilesMapping {
  my ($self, $profileSetName, $dbRlsId) = @_;

  my $transcriptTableId = $self->className2TableId('DoTS::Transcript');

  my $sql = "
SELECT g.source_id, p.profile_id
FROM Dots.Similarity s, Plasmodb.Profile p, Plasmodb.ProfileSet ps,
     Dots.Transcript t, Dots.GeneFeature g
WHERE ps.name = '$profileSetName'
AND ps.external_database_release_id = $dbRlsId
AND p.profile_set_id = ps.profile_set_id
AND s.query_table_id = p.subject_table_id
AND s.query_id = p.subject_row_id
AND $transcriptTableId = s.subject_table_id
AND t.na_feature_id = s.subject_id
AND g.na_feature_id = t.parent_id
";

  my $sth = $self->prepareAndExecute($sql);

  my $gene2ProfileIds = {};
  while (my @row = $sth->fetchrow_array()) {
    push(@{$gene2ProfileIds->{$row[0]}}, $row[1]);
  }
  return $gene2ProfileIds;
}

sub getMetaInfo {
  my ($self, $profileSetName, $dbRlsId) = @_;

  my $sql = "
SELECT ps.description, en.name, en.element_order
FROM plasmodb.profileSet ps, plasmodb.profileElementName en
WHERE ps.name = '$profileSetName'
AND ps.external_database_release_id = $dbRlsId
AND en.profile_set_id = ps.profile_set_id
ORDER BY en.element_order
";

  my $sth = $self->prepareAndExecute($sql);

  my $descrip;
  my @header;
  while (my @row = $sth->fetchrow_array()) {
    $descrip = $row[0];
    push(@header, $row[1]);
  }
  return ($descrip, "\t" . join("\t", @header)); # first header column empty
}

sub getAverageProfile {
  my ($self, $profileIds, $expectedElementCount) = @_;

  my @sum;

  my $idsString = join(",", @{$profileIds});
  my $sql = "
SELECT profile_id, profile_as_string
FROM plasmodb.profile
WHERE profile_id in ($idsString)
AND no_evidence_of_expr = 0
";

  my $sth = $self->prepareAndExecute($sql);

  my $profileCount;
  while (my ($profileId, $profileString) = $sth->fetchrow_array()) {
    $profileCount++;
    my @profile = split(/\t/, $profileString);

    if(scalar @profile != $expectedElementCount) {
      die "Profile $profileId does not have the expected number of Elements: $expectedElementCount";
    }

    for (my $i=0; $i<=$#profile; $i++) {
      $sum[$i] += $profile[$i];
    }
  }

  return map {sprintf("%.5f", $_/$profileCount) } @sum;
}

sub undoTables {
  my ($self) = @_;

  return ('PlasmoDB.ProfileElement',
	  'PlasmoDB.Profile',
	  'PlasmoDB.ProfileElementName',
	  'PlasmoDB.ProfileSet',
	 );
}

1;

