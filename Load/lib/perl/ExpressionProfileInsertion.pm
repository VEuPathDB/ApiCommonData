package ApiCommonData::Load::ExpressionProfileInsertion;

require Exporter;
@ISA = qw(Exporter);

@EXPORT = qw(parseInputFile processInputProfileSet makeProfileSet makeProfile);

use strict;
use Data::Dumper;
use GUS::Supported::Util;
use GUS::Model::ApiDB::Profile;
use GUS::Model::ApiDB::ProfileSet;
use GUS::Model::ApiDB::ProfileElement;
use GUS::Model::ApiDB::ProfileElementName;

use GUS::Model::DoTS::GeneFeature;

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
  my ($plugin, $dbRlsId, $header, $profileRows, $name, $descrip, $sourceIdType, $loadProfileElement,$isLogged,$base,$tolerateMissingIds, $averageReplicates,$optionalOrganismAbbrev) = @_;

  $plugin->log("Processing '$name'");

  my $profileSet = &makeProfileSet($plugin, $dbRlsId, $header, $name,
				    $descrip, $sourceIdType, $isLogged, $base);

  $profileSet->submit();


  my %eoToPen;
  foreach($profileSet->getChildren('ApiDB::ProfileElementName', 1)) {
    my $elementOrder = $_->getElementOrder();
    $eoToPen{$elementOrder} = $_;
  }


  my $count = 0;
  my $notFound = 0;

  if ($averageReplicates) {
    my @profileRowsNoReps = &_averageReplicates($plugin, $profileRows);
    $profileRows = \@profileRowsNoReps;
  }
  foreach my $profileRow (@$profileRows) {
    my $profile = &makeProfile($plugin, $profileRow, $profileSet,
				\%eoToPen,
				$sourceIdType,
				$tolerateMissingIds,
				$loadProfileElement,
			        $optionalOrganismAbbrev);
    if ($profile) {
      $profile->submit();
      $count++;
    } else {
      $notFound++;
    }
    if ($count % 10 == 0) {
      $plugin->log("$count profiles submitted");
      $plugin->undefPointerCache();
    }
  }
  $plugin->log("$count profiles submitted for '$name'. $notFound not found");
}

sub makeProfileSet {
  my ($plugin, $dbRlsId, $header, $name, $descrip, $sourceIdType, $isLogged, $base) = @_;
  $base ='' unless defined $base;

  my @header = @{$header};

  my $elementCount = scalar(@header);
  my $profileSet = GUS::Model::ApiDB::ProfileSet->
    new({name => $name,
	 description =>  $descrip,
	 source_id_type =>  $sourceIdType,
	 external_database_release_id => $dbRlsId,
	 element_count => $elementCount,
         is_logged => $isLogged,
         base => $base,
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
  my ($plugin, $profileRow, $profileSet, $eoToPen, $sourceIdType, $tolerateMissingIds, $loadProfileElement, $optionalOrganismAbbrev) = @_;

  my $subject_id;
  my $sourceId = shift(@$profileRow);

  my $elementCount = $profileSet->getElementCount();

  scalar(@$profileRow) == $elementCount || $plugin->error("Expected $elementCount elements, but found " . scalar(@$profileRow) . " in line: " . join ("\t", @$profileRow));

  my $subjectTableId;
  my $subjectRowId;

  if ($sourceIdType eq 'gene') {
    $subjectTableId = $plugin->className2TableId('DoTS::GeneFeature');
    $subjectRowId = &GUS::Supported::Util::getGeneFeatureId($plugin,$sourceId,0,$optionalOrganismAbbrev);
    if($subjectRowId){
	# ensure we are loading the source id from genefeature and not an alias
	my $geneFeature = GUS::Model::DoTS::GeneFeature->new({na_feature_id => $subjectRowId});

	unless($geneFeature->retrieveFromDB()) {

	    $plugin->error("No GeneFeature found for na_feature_id $subjectRowId");
	}

	$sourceId = $geneFeature->getSourceId();
    }

  } elsif ($sourceIdType eq 'oligo') {
    $subjectTableId = $plugin->className2TableId('DoTS::ExternalNaSequence');
    $subjectRowId = &_getExternalNaSequenceId($plugin, $sourceId);
  } elsif ($sourceIdType eq 'compound') {
    $subjectTableId = $plugin->className2TableId('ApiDB::PubChemCompound');

    $subjectRowId = &_getCompoundId($plugin, $sourceId);
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
	   subject_table_id => $subjectTableId,
	   subject_row_id => $subjectRowId,
	   no_evidence_of_expr => $plugin->{duds}->{$sourceId}? 1 : 0,
	   profile_as_string => join("\t", @$profileRow),
	  });

  $profile->setParent($profileSet);


  if($loadProfileElement){
    my $count = 1;
    foreach my $value (@$profileRow) {
      $value = undef if($value eq 'NA');
      $value=~s/\r//g;
      my $profileElement = GUS::Model::ApiDB::ProfileElement->
	new({value => $value });

      my $profileElementName = $eoToPen->{$count};

      $profileElement->setParent($profileElementName);
      $profile->addChild($profileElement);
      $count++;
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

sub _getCompoundId {
  my ($plugin, $sourceId) = @_;

  my $sql = "
SELECT pubchem_compound_id 
FROM ApiDB.pubchemcompound 
WHERE TO_CHAR(compound_id)  = '$sourceId'
AND property='MolecularWeight'
UNION
SELECT c.pubchem_compound_id
FROM SRes.dbref r, ApiDB.dbrefcompound l, ApiDB.pubchemcompound c
WHERE r.primary_identifier ='$sourceId'
AND r.db_ref_id = l.db_ref_id
AND l.compound_id = c.compound_id
AND c.property='MolecularWeight'";
  my $stmt = $plugin->prepareAndExecute($sql);
  my $comp_id = $stmt->fetchrow_array();
  return $comp_id;
}

