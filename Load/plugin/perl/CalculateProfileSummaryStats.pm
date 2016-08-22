package ApiCommonData::Load::Plugin::CalculateProfileSummaryStats;
#vvvvvvvvvvvvvvvvvvvvvvvvv GUS4_STATUS vvvvvvvvvvvvvvvvvvvvvvvvv
  # GUS4_STATUS | SRes.OntologyTerm              | auto   | absent
  # GUS4_STATUS | SRes.SequenceOntology          | auto   | absent
  # GUS4_STATUS | Study.OntologyEntry            | auto   | absent
  # GUS4_STATUS | SRes.GOTerm                    | auto   | absent
  # GUS4_STATUS | Dots.RNAFeatureExon            | auto   | absent
  # GUS4_STATUS | RAD.SageTag                    | auto   | absent
  # GUS4_STATUS | RAD.Analysis                   | auto   | absent
  # GUS4_STATUS | ApiDB.Profile                  | auto   | broken
  # GUS4_STATUS | Study.Study                    | auto   | absent
  # GUS4_STATUS | Dots.Isolate                   | auto   | absent
  # GUS4_STATUS | DeprecatedTables               | auto   | absent
  # GUS4_STATUS | Pathway                        | auto   | absent
  # GUS4_STATUS | DoTS.SequenceVariation         | auto   | absent
  # GUS4_STATUS | RNASeq Junctions               | auto   | absent
  # GUS4_STATUS | Simple Rename                  | auto   | absent
  # GUS4_STATUS | ApiDB Tuning Gene              | auto   | absent
  # GUS4_STATUS | Rethink                        | auto   | absent
  # GUS4_STATUS | dots.gene                      | manual | unreviewed
die 'This file has broken or unreviewed GUS4_STATUS rules.  Please remove this line when all are fixed or absent';
#^^^^^^^^^^^^^^^^^^^^^^^^^ End GUS4_STATUS ^^^^^^^^^^^^^^^^^^^^

@ISA = qw(GUS::PluginMgr::Plugin);

use strict;
use GUS::PluginMgr::Plugin;
use GUS::Model::ApiDB::Profile;
use Data::Dumper;

my $argsDeclaration =
[
   # profileSetNames and percentProfileSet are deprecated and may be removed in the future. please use profileSetSpecs
   stringArg({name           => 'profileSetNames',
	      descr          => 'Names of ProfileSets to update',
	      reqd           => 0,
	      constraintFunc => undef,
	      isList         => 1, }),

   stringArg({name           => 'percentProfileSet',
	      descr          => 'Name of the percents ProfileSet',
	      reqd           => 0,
	      constraintFunc => undef,
	      isList         => 0, }),

   stringArg({name           => 'profileSetSpecs',
	      descr          => 'ProfileSets name to update and percent `profileSetName1|percentProfileSet1,profileSetName2|percentProfileSet2`',
	      reqd           => 0,
	      constraintFunc => undef,
	      isList         => 0, }),


   fileArg({name           => 'timePointsMappingFile',
	    descr          => 'Maps the time points in these profile sets to a "universal" set of time points.  If omitted, then do not map timepoints',
	    reqd           => 0,
	    mustExist      => 1,
	    format         => 'Two column tab file: first column, local time points; second, universal time points',
	    constraintFunc => undef,
	    isList         => 0, }),

   stringArg({name => 'externalDatabaseSpec',
	      descr => 'External database of the profile sets (name|version format)',
	      constraintFunc=> undef,
	      reqd  => 1,
	      isList => 0
	     }),

];

my $purpose = <<PURPOSE;
Calculate summary statistics for the profiles in the specified profile sets.
PURPOSE

my $purposeBrief = <<PURPOSE_BRIEF;
Calculate summary statistics for the profiles in the specified profile sets.
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

  $self->initialize({ requiredDbVersion => 3.6,
		      cvsRevision       => '$Revision$',
		      name              => ref($self),
		      argsDeclaration   => $argsDeclaration,
		      documentation     => $documentation});

  return $self;
}

sub run {
  my ($self) = @_;

  ##set so doesn't update the algorithminvocation of updated objects
  $self->getDb()->setDoNotUpdateAlgoInvoId(1);

  my $timePointMap =
    $self->makeTimePointMap($self->getArg('timePointsMappingFile'));

  my $dbRlsId = $self->getExtDbRlsId($self->getArg('externalDatabaseSpec'));


  if($self->getArg('profileSetSpecs')){

      die "Do not use 'profileSetNames' and 'percentProfileSet' with 'profileSetSpecs', use only one set of then\n" if ($self->getArg('profileSetNames') || $self->getArg('percentProfileSet'));

      my @profileSetSpecs = split (/,/,$self->getArg('profileSetSpecs'));

      my $profilesCount = 0;

      foreach my $profileSetSpec (@profileSetSpecs){
      
	  my ($profileSetName,$percentiles)= split (/\|/,$profileSetSpec);
          my $percentsHash = $self->makePercentsHash($percentiles, $dbRlsId);
	  $profilesCount += $self->processProfileSet($profileSetName, $dbRlsId, $timePointMap,$percentsHash);
      }
       return "Calculated summary statistics for $profilesCount Profiles in ProfileSets: " . join(", ", @profileSetSpecs); 

  }elsif ($self->getArg('profileSetNames')){

      die "Do not use 'profileSetNames' and 'percentProfileSet' with 'profileSetSpecs', use only one set of then\n" if ($self->getArg('profileSetSpecs'));

      my $profileSetNames = $self->getArg('profileSetNames');

      my $percentsHash = $self->makePercentsHash($self->getArg('percentProfileSet'), $dbRlsId) if $self->getArg('percentProfileSet');

      my $profilesCount = 0;
      foreach my $profileSetName (@{$profileSetNames}) {
	  $profilesCount += $self->processProfileSet($profileSetName, $dbRlsId, $timePointMap, $percentsHash);
      }

      return "Calculated summary statistics for $profilesCount Profiles in ProfileSets: " . join(", ", @$profileSetNames);
  }else {
      die "Use either 'profileSetNames' or 'profileSetSpecs', but not both\n";
  }
}

sub makeTimePointMap {
  my ($self, $timePointMapFile) = @_;

  return undef unless $timePointMapFile;

  open(FILE, $timePointMapFile);

  my %map;

  my $header = <FILE>;

  while (<FILE>) {
    chomp;
    my @cols = split(/\t/, $_);
    $self->error("Line in $timePointMapFile does not have two columns: '$_'")
      unless scalar(@cols) == 2;
    $map{$cols[0]} = $cols[1];
  }
  return \%map;
}

sub makePercentsHash {
  my ($self, $percentsProfileSetName, $dbRlsId) = @_;

  my %percentsHash;
  my $sql = "
SELECT source_id, profile_as_string
FROM apidb.profile p, apidb.profileset ps
WHERE ps.name = '$percentsProfileSetName'
AND ps.external_database_release_id = $dbRlsId
AND p.profile_set_id = ps.profile_set_id
";

  my $sth = $self->prepareAndExecute($sql);

  $self->log("Reading percents profile set $percentsProfileSetName into memory");
  while (my ($sourceId, $profileString) = $sth->fetchrow_array()) {
    my @array = split(/\t/, $profileString);
    $percentsHash{$sourceId} = \@array;
  }
  return\%percentsHash;
}

sub processProfileSet {
  my ($self, $profileSetName, $dbRlsId, $timePointMap, $percentsHash) = @_;

  my $header = $self->getHeader($profileSetName, $dbRlsId);

  $self->log("Processing ProfileSet $profileSetName");

  my $sql = "
SELECT source_id, profile_as_string, no_evidence_of_expr, profile_id, ps.is_logged, ps.base
FROM apidb.profile p, apidb.profileset ps
WHERE ps.name = '$profileSetName'
AND ps.external_database_release_id = $dbRlsId
AND p.profile_set_id = ps.profile_set_id
";

  my $sth = $self->prepareAndExecute($sql);

  my $inductionSum = 0;
  my $statsById = {};
  my $dudCount = 0;
  my $profileCount = 0;
  my %sourceId2profileId;

  $self->log("  First pass to read profiles and compute statistics");
  while (my ($sourceId, $profileString, $dud, $profileId, $isLogged, $base)
	 = $sth->fetchrow_array()) {

    if ($dud == 1) {
      $dudCount++;
      next;
    }
    $sourceId2profileId{$sourceId} = $profileId;

    my @profile = split(/\t/, $profileString);

    my $naCount;
    foreach(@profile) {
      $naCount++ if($_ eq 'NA');
    }

    next if($naCount == scalar(@profile));

    my $profileHash = $self->makeProfileHash($sourceId,\@profile, $header);
    my $percentHash = $self->makeProfileHash($sourceId,
					     $percentsHash->{$sourceId},
					     $header);

    $statsById->{$sourceId} =
      $self->calculateSummaryStats($profileHash, $percentHash,
				   $timePointMap, $sourceId,
                                   $isLogged, $base);
    $inductionSum += $statsById->{$sourceId}->{ind_ratio};
    $profileCount++;
  }

  $self->secondPass($statsById, $inductionSum/$profileCount,
		    \%sourceId2profileId);
  $self->log("  Submitted statistics for $profileCount profiles (skipped $dudCount duds)");

  return $profileCount;
}

sub getHeader {
  my ($self, $profileSetName, $dbRlsId) = @_;

  my $sql = "
SELECT en.name
FROM apidb.profileSet ps, apidb.profileElementName en
WHERE ps.name = '$profileSetName'
AND ps.external_database_release_id = $dbRlsId
AND en.profile_set_id = ps.profile_set_id
ORDER BY en.element_order
";

  my $sth = $self->prepareAndExecute($sql);

  my $descrip;
  my @header;
  while (my @row = $sth->fetchrow_array()) {
    push(@header, $row[0]);
  }

  return \@header;
}

sub makeProfileHash {
  my ($self, $sourceId, $profile, $header) = @_;

  my $pCnt = scalar(@$profile);
  my $hCnt = scalar(@$header);
  $self->error("profile $sourceId (count: $pCnt) does not match header (count: $hCnt)")
    unless $pCnt == $hCnt;

  my %h;
  for (my $i=0; $i<scalar(@$profile); $i++) {
    my $h = $header->[$i];

    my $profileKey = $h;

    $h{$profileKey} = $profile->[$i];
  }

  return \%h;
}

sub secondPass {
  my ($self, $statsById, $inductionAvg, $sourceId2profileId) = @_;

  $self->log("  Second pass to compute average induction, and submit updated Profiles");

  my $profileCount = 0;
  foreach my $sourceId (keys %$statsById) {
    $profileCount++;
    my $profileId = $sourceId2profileId->{$sourceId};
    my $profile =
      GUS::Model::ApiDB::Profile->new({profile_id => $profileId});

    $profile->retrieveFromDB()
      || $self->error("Couldn't retrieve Profile with source_id '$sourceId'");

    my $stats = $statsById->{$sourceId};

    foreach my $attr (keys %$stats) {
      $profile->set($attr, $stats->{$attr});
    }

    $profile->set('ind_norm_by_med', $stats->{ind_ratio}/$inductionAvg) if $inductionAvg;

    $profile->submit();
    
    if ($profileCount % 1000 == 0){
	$self->log("    submitted $profileCount so far for this profile set");
	$self->undefPointerCache();
    }
      
  }
}

sub calculateSummaryStats {
    my ($self, $profileHashRef, $percentileHashRef, $timePointMappingRef, $sourceId, $isLogged, $base) = @_;
    my %profileHash = %{$profileHashRef};
    my %percentileHash = %{$percentileHashRef};
    my %timePointMapping = %{$timePointMappingRef} if $timePointMappingRef;

    my %resultHash;

    my $hashLength = 0;
    my $key1;
    foreach my $key (keys %profileHash) {
	$key1 = $key;
	$hashLength++;
    }

    my $max = $profileHash{$key1};
    my $min = $profileHash{$key1};
    my $maxKey = $key1;
    my $minKey = $key1;
    foreach my $key (keys %profileHash) {

      next if($profileHash{$key} eq 'NA');

	if($max < $profileHash{$key}) {
	    $max = $profileHash{$key};
	    $maxKey = $key;
	}
	if($min > $profileHash{$key}) {
	    $min = $profileHash{$key};
	    $minKey = $key;
	}
    }

    $resultHash{'max_expression'} = $max unless ($max eq 'NA');
    $resultHash{'min_expression'} = $min  unless ($min eq 'NA');
    $resultHash{'time_of_max_expr'} = $maxKey;
    $resultHash{'time_of_min_expr'} = $minKey;

    if($isLogged) {
      $resultHash{'ind_ratio'} = $base ** $max / $base ** $min;
    }
    else {
      if($min == 0) {
        $resultHash{'ind_ratio'} = $max;
      }
      else {
        $resultHash{'ind_ratio'} = $max/$min;
      }
    }

    if ($timePointMappingRef) {
      $resultHash{'equiv_max'} = $timePointMapping{$maxKey};
      $resultHash{'equiv_min'} = $timePointMapping{$minKey};
      $resultHash{'time_of_max_expr'} = $timePointMapping{$maxKey};
      $resultHash{'time_of_min_expr'} = $timePointMapping{$minKey};

    }

    my $maxPercentile = 0;
    foreach my $key (keys %percentileHash) {
	if($maxPercentile < $percentileHash{$key}) {
	    $maxPercentile = $percentileHash{$key};
	}
    }

    $resultHash{'max_percentile'} = $maxPercentile;

   return \%resultHash;
}


sub undoTables {
  my ($self) = @_;

  return ('ApiDB.Profile'
	 );
}


1;

