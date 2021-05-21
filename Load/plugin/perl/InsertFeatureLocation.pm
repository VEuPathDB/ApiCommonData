package ApiCommonData::Load::Plugin::InsertFeatureLocation;

@ISA = qw(GUS::PluginMgr::Plugin);

use strict;
use warnings;

use lib "$ENV{GUS_HOME}/lib/perl";

use GUS::PluginMgr::Plugin;
use GUS::Community::GeneModelLocations;

use GUS::Model::ApiDB::FeatureLocation;
use GUS::Model::ApiDB::GeneLocation;
use GUS::Model::ApiDB::TranscriptLocation;
use GUS::Model::ApiDB::ExonLocation;
use GUS::Model::ApiDB::CdsLocation;
use GUS::Model::ApiDB::UtrLocation;
use GUS::Model::ApiDB::IntronLocation;

# ----------------------------------------------------------
# Load Arguments
# ----------------------------------------------------------

my $argsDeclaration  =
  [
   stringArg({ name => 'ncbiTaxonId',
	       descr => '',
	       constraintFunc => undef,
	       reqd  => 1,
	       isList => 0,
	     }),
   enumArg({ name => 'mode',
	     descr => 'insert features created late in the workflow (such as tandem repeats, scaffold gaps, and ORFs) or early',
	     constraintFunc => undef,
	     reqd => 0,
	     isList => 0,
	     enum => 'early, late, all',
	     default => 'early'
	   }),
  ];

# ----------------------------------------------------------
# Documentation
# ----------------------------------------------------------

  my $description = <<DESCR;
For the specified taxon, populate feature location tables.
DESCR

  my $purpose = <<PURPOSE;
For the specified taxon, populate feature location tables.
PURPOSE

  my $purposeBrief = <<PURPOSEBRIEF;
For the specified taxon, populate feature location tables.
PURPOSEBRIEF

  my $notes = <<NOTES;
NOTES

  my $tablesAffected = <<AFFECT;
ApiDB.FeatureLocation
ApiDB.GeneLocation
ApiDB.TranscriptLocation
ApiDB.ExonLocation
ApiDB.CdsLocation
ApiDB.UtrLocation
ApiDB.IntronLocation
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

  my $ncbiTaxonId = $self->getArg('ncbiTaxonId');
  my $mode = $self->getArg('mode');
  if ($mode eq "late") {
    # late features are ScaffoldGapFeature, TandemRepeatFeature, LowComplexityNAFeature,
    # and miscellaneous features with the SO term 'orf'
    $self->insertOtherLocations($ncbiTaxonId, $mode);
  } else {
    $self->insertGeneModelLocations($ncbiTaxonId);
    $self->insertOtherLocations($ncbiTaxonId, $mode);
  }

  my $status = "inserted " . $self->{insertCount} . " records";
  return $status
}

sub insertGeneModelLocations {
  my ($self, $ncbiTaxonId) = @_;

  my $dbh = $self->getQueryHandle();
  $self->log("preparing Sequence Ontology query");
  my $soQuery = $dbh->prepare(<<SQL) or die $dbh->errstr;
      select gf.na_feature_id, gf.sequence_ontology_id
      from dots.GeneFeature gf, dots.NaSequence ns, sres.Taxon t
      where gf.na_sequence_id = ns.na_sequence_id
        and ns.taxon_id = t.taxon_id
        and t.ncbi_tax_id = $ncbiTaxonId
SQL

  $self->log("preparing external database release query");
  my $edrQuery = $dbh->prepare(<<SQL) or die $dbh->errstr;
    select distinct gf.external_database_release_id, gf.is_predicted 
    from dots.geneFeature gf, dots.NaSequence ns, sres.Taxon t
    where ns.na_sequence_id = gf.na_sequence_id
      and ns.taxon_id = t.taxon_id
      and t.ncbi_tax_id = $ncbiTaxonId
SQL

  $self->log("executing Sequence Ontology query");
  $soQuery->execute();
  my %geneSoMap;
  while(my ($featureId, $so) = $soQuery->fetchrow_array()) {
    $geneSoMap{$featureId} = $so;
  }
  $soQuery->finish();

  $self->log("executing external database release query");
  $edrQuery->execute();

  $self->log("fetching external database release query");
  while (my ($genomeExtDbRlsId, $isPredicted) = $edrQuery->fetchrow_array()) {
    foreach my $isTopLevel ((0, 1)) {

      my $geneModelLocations = GUS::Community::GeneModelLocations->new($dbh, $genomeExtDbRlsId, $isTopLevel);

      my $geneList = $geneModelLocations->getAllGeneIds();
      foreach my $geneId (@$geneList) {
	my $gmh = $geneModelLocations->getGeneModelHashFromGeneSourceId($geneId);

	my $bioperlFeatures = $geneModelLocations->bioperlFeaturesFromGeneSourceId($geneId);

	next if $isTopLevel == 0 && $gmh->{sequence_is_piece} == 0;

	foreach my $feature (@$bioperlFeatures) {


          if(GUS::Community::GeneModelLocations::getShortFeatureType($feature) eq 'Gene') {

	    my ($geneNaFeatureId) = $feature->get_tag_values("NA_FEATURE_ID");
	    my $seqOntId = $geneSoMap{$geneNaFeatureId};

	    my $loc
	      = GUS::Model::ApiDB::GeneLocation->
		new({'feature_source_id' => ($feature->get_tag_values("ID"))[0],
		     'sequence_source_id' => $feature->seq_id(),
		     'na_sequence_id' => ($feature->get_tag_values("NA_SEQUENCE_ID"))[0],
		     'na_feature_id' => ($feature->get_tag_values("NA_FEATURE_ID"))[0],
		     'start_min' => $feature->start(),
		     'end_max' => $feature->end(),
		     'is_reversed' => $feature->strand() == -1 ? 1 : 0,
		     'sequence_ontology_id' => $seqOntId,
		     'is_top_level' => $isTopLevel,
		     'external_database_release_id' => $genomeExtDbRlsId,
		    });
	    $loc->submit();
            $self->incrementInsertCounter();

	    $loc
	      = GUS::Model::ApiDB::FeatureLocation->
		new({'feature_type' => "GeneFeature",
                     'feature_source_id' => ($feature->get_tag_values("ID"))[0],
		     'sequence_source_id' => $feature->seq_id(),
		     'na_sequence_id' => ($feature->get_tag_values("NA_SEQUENCE_ID"))[0],
		     'na_feature_id' => ($feature->get_tag_values("NA_FEATURE_ID"))[0],
		     'start_min' => $feature->start(),
		     'end_max' => $feature->end(),
		     'is_reversed' => $feature->strand() == -1 ? 1 : 0,
		     'sequence_ontology_id' => $seqOntId,
		     'is_top_level' => $isTopLevel,
		     'external_database_release_id' => $genomeExtDbRlsId,
		    });
	    $loc->submit();
            $self->incrementInsertCounter();
	  }

          if($feature->primary_tag eq 'CDS') {
	    my $loc
	      = GUS::Model::ApiDB::CdsLocation->
		new({'protein_source_id' => ($feature->get_tag_values("PROTEIN_SOURCE_ID"))[0],
		     'transcript_source_id' => ($feature->get_tag_values("PARENT"))[0],
		     'sequence_source_id' => $feature->seq_id(),
		     'na_sequence_id' => ($feature->get_tag_values("NA_SEQUENCE_ID"))[0],
		     'start_min' => $feature->start(),
		     'end_max' => $feature->end(),
		     'is_reversed' => $feature->strand() == -1 ? 1 : 0,
		     'parent_id' => ($feature->get_tag_values("PARENT_NA_FEATURE_ID"))[0],
		     'is_top_level' => $isTopLevel,
		     'external_database_release_id' => $genomeExtDbRlsId,
		    });
	    $loc->submit();
            $self->incrementInsertCounter();

	    $loc
	      = GUS::Model::ApiDB::FeatureLocation->
		new({'feature_type' => "CDS",
		     'sequence_source_id' => $feature->seq_id(),
		     'na_sequence_id' => ($feature->get_tag_values("NA_SEQUENCE_ID"))[0],
		     'start_min' => $feature->start(),
		     'end_max' => $feature->end(),
		     'is_reversed' => $feature->strand() == -1 ? 1 : 0,
		     'parent_id' => ($feature->get_tag_values("PARENT_NA_FEATURE_ID"))[0],
		     'is_top_level' => $isTopLevel,
		     'external_database_release_id' => $genomeExtDbRlsId,
		    });
	    $loc->submit();
            $self->incrementInsertCounter();
	  }

	  if($feature->primary_tag() =~ /utr(3|5)prime/) {
	    my $utrDirection = $1;
	    my $loc
	      = GUS::Model::ApiDB::UtrLocation->
		new({
		     'sequence_source_id' => $feature->seq_id(),
		     'na_sequence_id' => ($feature->get_tag_values("NA_SEQUENCE_ID"))[0],
		     'start_min' => $feature->start(),
		     'end_max' => $feature->end(),
		     'is_reversed' => $feature->strand() == -1 ? 1 : 0,
		     'direction' => $utrDirection,
		     'parent_id' => ($feature->get_tag_values("PARENT_NA_FEATURE_ID"))[0],
		     'is_top_level' => $isTopLevel,
		     'external_database_release_id' => $genomeExtDbRlsId,
		    });
	    $loc->submit();
            $self->incrementInsertCounter();

	    $loc
	      = GUS::Model::ApiDB::FeatureLocation->
		new({'feature_type' => "UTR",
		     'sequence_source_id' => $feature->seq_id(),
		     'na_sequence_id' => ($feature->get_tag_values("NA_SEQUENCE_ID"))[0],
		     'start_min' => $feature->start(),
		     'end_max' => $feature->end(),
		     'is_reversed' => $feature->strand() == -1 ? 1 : 0,
		     'parent_id' => ($feature->get_tag_values("PARENT_NA_FEATURE_ID"))[0],
		     'is_top_level' => $isTopLevel,
		     'external_database_release_id' => $genomeExtDbRlsId,
		    });
	    $loc->submit();
            $self->incrementInsertCounter();

	  }

          if(GUS::Community::GeneModelLocations::getShortFeatureType($feature) eq 'Transcript') {
	    my $loc
	      = GUS::Model::ApiDB::TranscriptLocation->
		new({
		     'feature_source_id' => ($feature->get_tag_values("ID"))[0],
		     'sequence_source_id' => $feature->seq_id(),
		     'na_sequence_id' => ($feature->get_tag_values("NA_SEQUENCE_ID"))[0],
		     'na_feature_id' => ($feature->get_tag_values("NA_FEATURE_ID"))[0],
		     'start_min' => $feature->start(),
		     'end_max' => $feature->end(),
		     'is_reversed' => $feature->strand() == -1 ? 1 : 0,
		     'parent_id' => ($feature->get_tag_values("PARENT_NA_FEATURE_ID"))[0],
		     'is_top_level' => $isTopLevel,
		     'external_database_release_id' => $genomeExtDbRlsId,
		    });
	    $loc->submit();
            $self->incrementInsertCounter();

	    $loc
	      = GUS::Model::ApiDB::FeatureLocation->
		new({'feature_type' => "Transcript",
		     'feature_source_id' => ($feature->get_tag_values("ID"))[0],
		     'sequence_source_id' => $feature->seq_id(),
		     'na_sequence_id' => ($feature->get_tag_values("NA_SEQUENCE_ID"))[0],
		     'na_feature_id' => ($feature->get_tag_values("NA_FEATURE_ID"))[0],
		     'start_min' => $feature->start(),
		     'end_max' => $feature->end(),
		     'is_reversed' => $feature->strand() == -1 ? 1 : 0,
		     'parent_id' => ($feature->get_tag_values("PARENT_NA_FEATURE_ID"))[0],
		     'is_top_level' => $isTopLevel,
		     'external_database_release_id' => $genomeExtDbRlsId,
		    });
	    $loc->submit();
            $self->incrementInsertCounter();

	    # have bioperl calculate the intron coords for the transcript
	    # NOTE:  the parent of the intron will be the transcript not the gene (may be some redundancy)

	    unless($isPredicted) {
	      foreach my $intron ($feature->introns()) {
		my $intronLocation = $intron->location();

		my $loc
		  = GUS::Model::ApiDB::IntronLocation->
		    new({
			 'sequence_source_id' => $feature->seq_id(),
			 'na_sequence_id' => ($feature->get_tag_values("NA_SEQUENCE_ID"))[0],
			 'start_min' => $intronLocation->start(),
			 'end_max' => $intronLocation->end(),
			 'is_reversed' => $feature->strand() == -1 ? 1 : 0,
			 'parent_id' => ($feature->get_tag_values("NA_FEATURE_ID"))[0],
			 'is_top_level' => $isTopLevel,
			 'external_database_release_id' => $genomeExtDbRlsId,
			});
		$loc->submit();
		$self->incrementInsertCounter();

		$loc
		  = GUS::Model::ApiDB::FeatureLocation->
		    new({'feature_type' => "Intron",
			 'sequence_source_id' => $feature->seq_id(),
			 'na_sequence_id' => ($feature->get_tag_values("NA_SEQUENCE_ID"))[0],
			 'start_min' => $intronLocation->start(),
			 'end_max' => $intronLocation->end(),
			 'is_reversed' => $feature->strand() == -1 ? 1 : 0,
			 'parent_id' => ($feature->get_tag_values("NA_FEATURE_ID"))[0],
			 'is_top_level' => $isTopLevel,
			 'external_database_release_id' => $genomeExtDbRlsId,
			});
		$loc->submit();
		$self->incrementInsertCounter();
	      }
	    }
	  }

          if($feature->primary_tag eq 'exon') {
	    my $loc
	      = GUS::Model::ApiDB::ExonLocation->
		new({
		     'feature_source_id' => ($feature->get_tag_values("ID"))[0],
		     'sequence_source_id' => $feature->seq_id(),
		     'na_sequence_id' => ($feature->get_tag_values("NA_SEQUENCE_ID"))[0],
		     'na_feature_id' => ($feature->get_tag_values("NA_FEATURE_ID"))[0],
		     'start_min' => $feature->start(),
		     'end_max' => $feature->end(),
		     'is_reversed' => $feature->strand() == -1 ? 1 : 0,
		     'parent_id' => ($feature->get_tag_values("GENE_NA_FEATURE_ID"))[0],
		     'is_top_level' => $isTopLevel,
		     'external_database_release_id' => $genomeExtDbRlsId,
		    });
	    $loc->submit();
            $self->incrementInsertCounter();

	    $loc
	      = GUS::Model::ApiDB::FeatureLocation->
		new({'feature_type' => "ExonFeature",
		     'feature_source_id' => ($feature->get_tag_values("ID"))[0],
		     'sequence_source_id' => $feature->seq_id(),
		     'na_sequence_id' => ($feature->get_tag_values("NA_SEQUENCE_ID"))[0],
		     'na_feature_id' => ($feature->get_tag_values("NA_FEATURE_ID"))[0],
		     'start_min' => $feature->start(),
		     'end_max' => $feature->end(),
		     'is_reversed' => $feature->strand() == -1 ? 1 : 0,
		     'parent_id' => ($feature->get_tag_values("GENE_NA_FEATURE_ID"))[0],
		     'is_top_level' => $isTopLevel,
		     'external_database_release_id' => $genomeExtDbRlsId,
		    });
	    $loc->submit();
            $self->incrementInsertCounter();
	  }
	}
      }
    }
  } # while (fetch edrQuery)
  $self->log("finished fetching external database release query");
}

sub insertOtherLocations {
  my ($self, $ncbiTaxonId, $mode) = @_;

  # get feature locations from NaFeature and NaLocation

  my $latePredicate;
  if ($mode eq "late") {
    $latePredicate = <<SQL;
            and nf.subclass_view not in ('ScaffoldGapFeature', 'TandemRepeatFeature', 'LowComplexityNAFeature')
            and (nf.subclass_view != 'Miscellaneous'
                 or nf.sequence_ontology_id is null
                 or nf.sequence_ontology_id != (select ontology_term_id from sres.OntologyTerm where name = 'ORF'))
SQL
  } else {
    $latePredicate = <<SQL;
            and (nf.subclass_view in ('ScaffoldGapFeature', 'TandemRepeatFeature', 'LowComplexityNAFeature')
                 or nf.subclass_view = 'Miscellaneous'
                    and nf.sequence_ontology_id = (select ontology_term_id from sres.OntologyTerm where name = 'ORF'))
SQL
  }

  my $sqlString = <<SQL;
    select case
              when nf.subclass_view = 'GeneFeature'
                   and nf.is_predicted = 1
                then 'GenePrediction'
              when nf.subclass_view = 'Miscellaneous' 
                   and nf.is_predicted = 1
                then 'Prediction'
              else nf.subclass_view
            end as feature_type,
            nf.source_id as feature_source_id, ns.source_id as sequence_source_id,
            nf.na_sequence_id, nf.na_feature_id,
            least(nl.start_min, nl.end_max) as start_min,
            greatest(nl.start_min, nl.end_max) as end_max,
            nl.is_reversed, nf.parent_id, nf.sequence_ontology_id,
            case
              when sp.sequence_piece_id is null then 1
              else 0
            end as is_top_level,
            nf.external_database_release_id
     from dots.NaFeature nf, dots.NaLocation nl, dots.NaSequence ns,
          dots.ExonFeature ef, sres.TaxonName tn, sres.Taxon t, dots.SequencePiece sp
     where nf.na_feature_id = nl.na_feature_id
       and nf.na_sequence_id = ns.na_sequence_id
       and nf.na_sequence_id = sp.piece_na_sequence_id(+)
       and nl.na_feature_id = ef.na_feature_id(+)
       and ns.taxon_id = tn.taxon_id
       and tn.name_class = 'scientific name'
       and nf.subclass_view not in ('GeneFeature', 'ExonFeature', 'Transcript')
       and ns.taxon_id = t.taxon_id
       and t.ncbi_tax_id = $ncbiTaxonId
     $latePredicate
     union
     select -- virtual feature locations mapped through SequencePiece
            case
              when nf.subclass_view = 'GeneFeature'
                   and nf.is_predicted = 1
                then 'GenePrediction'
              else nf.subclass_view
            end as feature_type,
            nf.source_id as feature_source_id, scaffold.source_id as sequence_source_id,
            sp.virtual_na_sequence_id, nf.na_feature_id,
            case
              when sp.strand_orientation in ('-', '-1')
                then sp.distance_from_left + sp.end_position - greatest(nl.start_min, nl.start_max, nl.end_min, nl.end_max)  + 1
                else sp.distance_from_left + least(nl.start_min, nl.start_max, nl.end_min, nl.end_max) - sp.start_position  + 1
            end as start_min,
            case
              when sp.strand_orientation in ('-', '-1')
                then sp.distance_from_left + sp.end_position - least(nl.start_min, nl.start_max, nl.end_min, nl.end_max) + 1
              else sp.distance_from_left + greatest(nl.start_min, nl.start_max, nl.end_min, nl.end_max) - sp.start_position + 1
            end as end_max,
            case
              when sp.strand_orientation in ('-', '-1')
              then decode(nvl(nl.is_reversed, 0),
                          0, 1,  1, 0,  1)
              else nl.is_reversed
            end as is_reversed,
            nf.parent_id, nf.sequence_ontology_id,
            1 as is_top_level,
            nf.external_database_release_id
     from dots.NaFeature nf, dots.NaLocation nl, dots.NaSequence contig,
          dots.SequencePiece sp, dots.NaSequence scaffold, dots.ExonFeature ef,
          sres.TaxonName tn, sres.Taxon t
     where nf.na_feature_id = nl.na_feature_id
       and nf.na_sequence_id = contig.na_sequence_id
       and nf.na_sequence_id = sp.piece_na_sequence_id
       and sp.start_position <= nl.start_min
       and sp.end_position >= nl.end_max
       and sp.virtual_na_sequence_id = scaffold.na_sequence_id
       and nl.na_feature_id = ef.na_feature_id(+)
       and contig.taxon_id = tn.taxon_id
       and tn.name_class = 'scientific name'
       and nf.subclass_view not in ('GeneFeature', 'ExonFeature', 'Transcript')
       and contig.taxon_id = t.taxon_id
       and t.ncbi_tax_id = $ncbiTaxonId
     $latePredicate
SQL

  $self->logDebug("NaFeature query:\n$sqlString\n");

  my $dbh = $self->getQueryHandle();
  $self->log("preparing NaFeature query");
  my $query = $dbh->prepare($sqlString) or die $dbh->errstr;

  $self->log("executing NaFeature query");
  $query->execute();

  $self->log("fetching NaFeature query");
  while (my ($feature_type, $feature_source_id, $sequence_source_id, $na_sequence_id,
	     $na_feature_id, $start_min, $end_max, $is_reversed, $parent_id, $sequence_ontology_id,
	     $is_top_level, $external_database_release_id) = $query->fetchrow_array()) {

    my $loc
      = GUS::Model::ApiDB::FeatureLocation->
	new({
	     'feature_type' => $feature_type,
	     'feature_source_id' => $feature_source_id,
	     'sequence_source_id' => $sequence_source_id,
	     'na_sequence_id' => $na_sequence_id,
	     'na_feature_id' => $na_feature_id,
	     'start_min' => $start_min,
	     'end_max' => $end_max,
	     'is_reversed' => $is_reversed,
	     'parent_id' => $parent_id,
	     'sequence_ontology_id' => $sequence_ontology_id,
	     'is_top_level' => $is_top_level,
	     'external_database_release_id' => $external_database_release_id,
	    });
    $loc->submit();
    $self->incrementInsertCounter();
  }
  $self->log("finished fetching NaFeature query");

}

sub incrementInsertCounter {
my ($self) = @_;

$self->{insertCount}++;
unless ($self->{insertCount} % 5000) {
	$self->log("Inserted $self->{insertCount} records");
  $self->undefPointerCache();
}

}

sub undoTables {
  return ('ApiDB.FeatureLocation',
          'ApiDB.GeneLocation',
          'ApiDB.TranscriptLocation',
          'ApiDB.ExonLocation',
          'ApiDB.CdsLocation',
          'ApiDB.UtrLocation',
          'ApiDB.IntronLocation',
	 );
}
