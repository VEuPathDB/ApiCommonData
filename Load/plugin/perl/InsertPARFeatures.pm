package ApiCommonData::Load::Plugin::InsertPARFeatures;

@ISA = qw(GUS::PluginMgr::Plugin);

use strict;
use warnings;

use lib "$ENV{GUS_HOME}/lib/perl";

use DBI;
use DBD::Oracle;
use GUS::Model::ApiDB::FeatureLocation;
use GUS::PluginMgr::Plugin;
use GUS::Community::GeneModelLocations;
use GUS::Model::ApiDB::FeatureLocation;
use GUS::Model::DoTS::NASequence;
use Bio::Location::Simple;
use Bio::Coordinate::Pair;
use Data::Dumper;

# ----------------------------------------------------------
# Load Arguments
# ----------------------------------------------------------

my $argsDeclaration  =
  [
   fileArg({name           => 'mappingFile',
            descr          => 'file containing mapping of pseudoautosomal regions',
            reqd           => 1,
            mustExist      => 1,
            format         => '',
            constraintFunc => undef,
            isList         => 0, }),
  ];

# ----------------------------------------------------------
# Documentation
# ----------------------------------------------------------

  my $description = <<DESCR;
Lift over features in pseudoautosomal regions.
DESCR

  my $purpose = <<PURPOSE;
Lift over features in pseudoautosomal regions.
PURPOSE

  my $purposeBrief = <<PURPOSEBRIEF;
Lift over features in pseudoautosomal regions.
PURPOSEBRIEF

  my $notes = <<NOTES;
NOTES

  my $tablesAffected = <<AFFECT;
ApiDB.FeatureLocation
AFFECT

  my $tablesDependedOn = <<TABD;
TABD

  my $howToRestart = <<RESTART;
No restart provided. Undo and re-run.
RESTART

  my $failureCases = <<FAIL;
FAIL

  my $documentation = { purpose          => $purpose,
			purposeBrief     => $purposeBrief,
			tablesAffected   => $tablesAffected,
			tablesDependedOn => $tablesDependedOn,
			howToRestart     => $howToRestart,
			failureCases     => $failureCases,
			notes            => $notes
		      };


sub new {
  my ($class) = @_;
  my $self = {};
  bless($self, $class);

  $self->initialize ({ requiredDbVersion => 4.0,
			cvsRevision => '$Revision$',
			name => ref($self),
			argsDeclaration => $argsDeclaration,
			documentation => $documentation
		      });

  $self->{insertCount} = 0;
  return $self;
}

sub run {
  my ($self) = @_;

  my $dbh = $self->getQueryHandle();

  my $queryStmt = $dbh->prepare(<<SQL) or die $dbh->errstr;
   select feature_type, feature_source_id, sequence_source_id, na_sequence_id,
          na_feature_id, start_min, end_max, is_reversed, parent_id,
          sequence_ontology_id, is_top_level, external_database_release_id
   from apidb.FeatureLocation
   where sequence_source_id = ?
     and end_max >= ?
     and start_min <= ?
   order by feature_type, start_min
SQL

  my $mappingFile = "parMap.dat";

  open (my $fh, "<", $mappingFile) or die "can't open file \"$mappingFile\"";
  while (<$fh>) {
    my ($fromId, $fromStart, $fromEnd, $toId, $toStart, $toEnd);

    # parse location mapping
    if ($_ =~ "(.*):(.*)-(.*)\t(.*):(.*)-(.*)\n") {
      $toId = $1;
      $toStart = $2;
      $toEnd = $3;
      $fromId = $4;
      $fromStart = $5;
      $fromEnd = $6;
      # print "from $fromId at $fromStart to $fromEnd onto $toId at $toStart to $toEnd is my mapping\n";
    } else {
      die "could not parse mapping \"$_\"";
    }

    # get na_sequence_id
    my $naSequence
      = GUS::Model::DoTS::NASequence->new({ source_id => $toId });
    $naSequence->retrieveFromDB();

    # make mapping
    my $fromRegion = Bio::Location::Simple->new( -seq_id => $fromId,
						 -start => $fromStart,
						 -end =>  $fromEnd,
						 -strand => '+1' );

    my $toRegion = Bio::Location::Simple->new( -seq_id => $toId,
					       -start => $toStart,
					       -end =>  $toEnd,
					       -strand => '+1' );

    my $agp = Bio::Coordinate::Pair->new( -in  => $fromRegion, -out => $toRegion );

    # find all features in "from" region
    $queryStmt->execute($fromId, $fromStart, $fromEnd) or die $dbh->errstr;
    while (my ($featureType, $featureSourceId, $sequenceSourceId, $naSequenceId,
	       $naFeatureId, $startMin, $endMax, $isReversed, $parentId,
	       $sequenceOntologyId, $isTopLevel, $externalDatabaseReleaseId)
	   = $queryStmt->fetchrow_array()) {

      # print "got $featureType $featureSourceId\n";

      my $unmappedFeature = Bio::Location::Simple->
	new( -seq_id => $fromId, -start =>   $startMin, -end =>  $endMax,
	     -strand => $isReversed ? "-1" : "+1" );
      my $mappedFeature = $agp->map($unmappedFeature);

      my $featureLocation
	= GUS::Model::ApiDB::FeatureLocation->new({
						   feature_type => $featureType,
						   feature_source_id => $featureSourceId,
						   sequence_source_id => $toId,
						   na_sequence_id => $naSequence->getId(),
						   na_feature_id => $naFeatureId,
						   start_min => $mappedFeature->start,
						   end_max => $mappedFeature->end,
						   is_reversed => $isReversed,
						   parent_id => $parentId,
						   sequence_ontology_id => $sequenceOntologyId,
						   is_top_level => 0,
						   external_database_release_id => $externalDatabaseReleaseId
						  });

      $featureLocation->submit() unless ($featureLocation->retrieveFromDB());
    }

    $queryStmt->finish() or die $dbh->errstr;

  }
  close $fh;

  my $status = "inserted " . $self->{insertCount} . " records";
  return $status
}


sub undoTables {
  return ('ApiDB.FeatureLocation',
	 );
}
