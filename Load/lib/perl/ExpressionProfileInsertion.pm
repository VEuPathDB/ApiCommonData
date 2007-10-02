package ApiCommonData::Load::ExpressionProfileInsertion;

require Exporter;
@ISA = qw(Exporter);

@EXPORT = qw(parseInputFile processInputProfileSet makeProfileSet makeProfile);

use strict;
use Data::Dumper;
use ApiCommonData::Load::Util;
use GUS::Model::ApiDB::Profile;
use GUS::Model::ApiDB::ProfileSet;
use GUS::Model::ApiDB::ProfileElement;
use GUS::Model::ApiDB::ProfileElementName;

# parse an input file into in-memory structures
sub parseInputFile {
  my ($plugin, $file, $name, $skipSecondRow) = @_;

  $plugin->log("Parsing $file as '$name'");
  open(PROFILES_FILE, $file);

  my $header = <PROFILES_FILE>;
  chomp($header);
  my @header = split(/\t/, $header);
  shift(@header);   # lose column heading for the sourceId column
  <PROFILES_FILE> if $skipSecondRow;
  my $profileRows;
  while (<PROFILES_FILE>) {
    chomp;
    next if /^\s*$/;
    next if /^EMPTY/;
    my @values = split(/\t/, $_);
    push(@$profileRows, \@values);
  }
  return (\@header, $profileRows)
}

# build a profile set and its profiles from in-memory data structures
sub processInputProfileSet {
  my ($plugin, $dbRlsId, $header, $profileRows, $name, $descrip, $sourceIdType, $loadProfileElement, $tolerateMissingIds, $averageReplicates) = @_;

  $plugin->log("Processing '$name'");

  my $profileSet = &makeProfileSet($plugin, $dbRlsId, $header, $name,
				    $descrip, $sourceIdType);

  $profileSet->submit();
  my $profileSetId = $profileSet->getId();
  my $elementCount = $profileSet->getElementCount();

  my $count = 0;
  my $notFound = 0;

  if ($averageReplicates) {
    my @profileRowsNoReps = &_averageReplicates($plugin, $profileRows);
    $profileRows = \@profileRowsNoReps;
  }
  foreach my $profileRow (@$profileRows) {
    my $profile = &makeProfile($plugin, $profileRow, $profileSetId,
				$elementCount,
				$sourceIdType,
				$tolerateMissingIds,
				$loadProfileElement);
    if ($profile) {
      $profile->submit();
      $count++;
    } else {
      $notFound++;
    }
    if ($count % 100 == 0) {
      $plugin->log("$count profiles submitted");
      $plugin->undefPointerCache();
    }
  }
  $plugin->log("$count profiles submitted for '$name'. $notFound not found");
}

sub makeProfileSet {
  my ($plugin, $dbRlsId, $header, $name, $descrip, $sourceIdType) = @_;

  my @header = @{$header};

  my $elementCount = scalar(@header);
  my $profileSet = GUS::Model::ApiDB::ProfileSet->
    new({name => $name,
	 description =>  $descrip,
	 source_id_type =>  $sourceIdType,
	 external_database_release_id => $dbRlsId,
	 element_count => $elementCount,
	});

  my $count = 1;
  foreach my $elementName (@header) {
    my $profileElementName = GUS::Model::ApiDB::ProfileElementName->
      new({name => $elementName, 
	     element_order => $count++
	  });
    $profileSet->addChild($profileElementName);
  }

  return $profileSet;
}

sub makeProfile {
  my ($plugin, $profileRow, $profileSetId, $elementCount, $sourceIdType, $tolerateMissingIds, $loadProfileElement) = @_;

  my $subject_id;
  my $sourceId = shift(@$profileRow);

  scalar(@$profileRow) == $elementCount || $plugin->error("Expected $elementCount elements, but found " . scalar(@$profileRow) . " in line: " . join ("\t", @$profileRow));

  my $subjectTableId;
  my $subjectRowId;

  if ($sourceIdType eq 'gene') {
    $subjectTableId = $plugin->className2TableId('DoTS::GeneFeature');
    $subjectRowId = &ApiCommonData::Load::Util::getGeneFeatureId($plugin,
								 $sourceId);
  } elsif ($sourceIdType eq 'oligo') {
    $subjectTableId = $plugin->className2TableId('DoTS::ExternalNaSequence');
    $subjectRowId = &_getExternalNaSequenceId($plugin, $sourceId);
  }

  if ($subjectTableId && !$subjectRowId) {
    if ($tolerateMissingIds) {
      $plugin->log("No $sourceIdType found for '$sourceId'");
      return 0;
    } else {
      $plugin->userError("Can't find $sourceIdType for source id '$sourceId'");
    }
  }

  my $profile = GUS::Model::ApiDB::Profile->
      new({source_id => $sourceId,
	   profile_set_id => $profileSetId,
	   subject_table_id => $subjectTableId,
	   subject_row_id => $subjectRowId,
	   no_evidence_of_expr => $plugin->{duds}->{$sourceId}? 1 : 0,
	   profile_as_string => join("\t", @$profileRow),
	  });

  if($loadProfileElement){
    my $count = 1;
    foreach my $value (@$profileRow) {
      my $profileElement = GUS::Model::ApiDB::ProfileElement->
	new({value => $value,
	     element_order => $count++
	    });
      $profile->addChild($profileElement);
    }
  }

  return $profile;
}

############### private subs #########################################

sub _averageReplicates {
  my ($plugin, $profileRows) = @_;

  $plugin->log("Averaging replicates (if any)");

  my %profiles;
  my @profiles;
  my $inputCount;

  foreach my $row (@$profileRows) {
    $inputCount++;
    my $sourceId = shift(@$row);
    push(@{$profiles{$sourceId}}, $row);
  }

  foreach my $sourceId (keys %profiles) {
    my @sum;
    foreach my $replicate (@{$profiles{$sourceId}}) {

      for (my $i=0; $i<scalar(@$replicate); $i++) {
	$sum[$i] += $replicate->[$i];
      }
    }

    my @avg = map { $_ / scalar(@{$profiles{$sourceId}})} @sum;
    push(@profiles, [$sourceId, @avg]);
  }
  $plugin->log("Original profiles: $inputCount.  After averaging replicates: " . scalar(@profiles));

  return @profiles;
}

sub _getExternalNaSequenceId {
  my ($plugin, $sourceId) = @_;

  if (!$plugin->{naSequenceIds}) {
    $plugin->{naSequenceIds} = {};
    my $sql = "
SELECT source_id, na_sequence_id
FROM Dots.ExternalNaSequence extSeq, SRes.SequenceOntology so
WHERE so.term_name = 'oligo'
AND extSeq.sequence_ontology_id = so.sequence_ontology_id
";
    my $stmt = $plugin->prepareAndExecute($sql);
    while ( my($sourceId, $naSequenceId) = $stmt->fetchrow_array()) {
      $plugin->{naSequenceIds}->{$sourceId} = $naSequenceId;
    }
    
  }

  my $naSeqId = $plugin->{naSequenceIds}->{$sourceId};

  return $naSeqId;
}
