package ApiCommonData::Load::Plugin::InsertVirtualBlatAlign;

@ISA = qw(GUS::PluginMgr::Plugin);

use strict;
use warnings;

use lib "$ENV{GUS_HOME}/lib/perl";

use GUS::PluginMgr::Plugin;
use GUS::Model::DoTS::BLATAlignment;

# ----------------------------------------------------------
# Load Arguments
# ----------------------------------------------------------

  my $argsDeclaration  =
    [
     stringArg({ name => 'ncbiTaxonId',
		 descr => '',
		 constraintFunc=> undef,
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
For the specified taxon, copy any BlatAlignment records on sequence pieces to the corresponding virtual sequence
DESCR

  my $purpose = <<PURPOSE;
PURPOSE

  my $purposeBrief = <<PURPOSEBRIEF;
Add project organism name mappings
PURPOSEBRIEF

  my $notes = <<NOTES;
NOTES

  my $tablesAffected = <<AFFECT;
DoTS.BLATAlignment
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

  return $self;
}

sub run {
  my ($self) = @_;

  my $ncbiTaxonId = $self->getArg('ncbiTaxonId');

  # "early" mode means ESTs; "late" mode means everything else
  my $modePredicate;
  if ($self->getArg('mode') eq "early") {
    $modePredicate = <<SQL;
         and queryseq.sequence_ontology_id
               in (select ontology_term_id
                   from sres.OntologyTerm
                   where name = 'EST')
SQL
  } elsif ($self->getArg('mode') eq "late") {
    $modePredicate = <<SQL;
         and queryseq.sequence_ontology_id
               NOT in (select ontology_term_id
                       from sres.OntologyTerm
                       where name = 'EST')
SQL
  }

	my $sql = <<SQL;
				SELECT blat_alignment_id, query_na_sequence_id, target_na_sequence_id,
               query_table_id, query_taxon_id, query_external_db_release_id,
               target_table_id, target_taxon_id, target_external_db_release_id,
               is_consistent, is_genomic_contaminant, unaligned_3p_bases,
               unaligned_5p_bases, has_3p_polya, has_5p_polya, is_3p_complete,
               is_5p_complete, percent_identity, max_query_gap, max_target_gap,
               number_of_spans, query_start, query_end, target_start, target_end,
               is_reversed, query_bases_aligned, repeat_bases_aligned, num_ns, score,
               is_best_alignment, blat_alignment_quality_id, blocksizes, qstarts,
               tstarts, sp.virtual_na_sequence_id, sp.distance_from_left,
               sp.start_position, sp.end_position, sp.strand_orientation,
               piece.length, vti.table_id as virtual_target_table_id
        FROM dots.BlatAlignment ba
        	LEFT JOIN dots.SequencePiece sp ON ba.target_na_sequence_id = sp.piece_na_sequence_id
        	INNER JOIN dots.NaSequence piece ON ba.target_na_sequence_id = piece.na_sequence_id
        	INNER JOIN dots.NaSequence virtualseq ON sp.virtual_na_sequence_id = virtualseq.na_sequence_id
        	INNER JOIN core.TableInfo vti ON virtualseq.subclass_view = vti.name
        	INNER JOIN dots.NaSequence queryseq ON ba.query_na_sequence_id = queryseq.na_sequence_id
        WHERE
          sp.start_position <= target_start
          and sp.end_position >= target_end
          and ba.target_taxon_id = (select taxon_id from sres.Taxon where ncbi_tax_id = $ncbiTaxonId)
          $modePredicate
SQL

  my $dbh = $self->getQueryHandle();
  my $queryHandle = $dbh->prepare($sql) or die $dbh->errstr;
  $queryHandle->execute();

  my ($virtual_target_start, $virtual_target_end, $virtual_tstarts);
  my $recordCount = 0;

  while (my ($blat_alignment_id, $query_na_sequence_id, $target_na_sequence_id,
	     $query_table_id, $query_taxon_id, $query_external_db_release_id,
	     $target_table_id, $target_taxon_id, $target_external_db_release_id,
	     $is_consistent, $is_genomic_contaminant, $unaligned_3p_bases,
	     $unaligned_5p_bases, $has_3p_polya, $has_5p_polya, $is_3p_complete,
	     $is_5p_complete, $percent_identity, $max_query_gap, $max_target_gap,
	     $number_of_spans, $query_start, $query_end, $target_start, $target_end,
	     $is_reversed, $query_bases_aligned, $repeat_bases_aligned, $num_ns, $score,
	     $is_best_alignment, $blat_alignment_quality_id, $blocksizes, $qstarts,
	     $tstarts, $virtual_na_sequence_id, $distance_from_left, $start_position, $end_position,
	     $strand_orientation, $length, $virtual_target_table_id)
	 = $queryHandle->fetchrow_array()) {

    if ($strand_orientation eq '-') {
      $virtual_target_start = $distance_from_left + $end_position - $target_end + 1;
      $virtual_target_end = $distance_from_left + $end_position - $target_start + 1;
      $virtual_tstarts = &getReversedTstarts($distance_from_left,$end_position,$tstarts,$blocksizes);
      $blocksizes = join(',', reverse split(',', $blocksizes));
      $is_reversed = $is_reversed == 1 ? 0 : 1;
    } else {
      $virtual_target_start = $target_start + $distance_from_left - $start_position + 1;
      $virtual_target_end = $target_end + $distance_from_left - $start_position + 1;
      $virtual_tstarts = join( ',', map{ $_ + $distance_from_left - $start_position + 1 } split( /,/, $tstarts));
    }

    # insert virtual locations
    my $ba
      = GUS::Model::DoTS::BLATAlignment->
	new({'query_na_sequence_id' => $query_na_sequence_id,
	     'target_na_sequence_id' => $virtual_na_sequence_id,
	     'query_table_id' => $query_table_id,
	     'query_taxon_id' => $query_taxon_id,
	     'query_external_db_release_id' => $query_external_db_release_id,
	     'target_table_id' => $virtual_target_table_id,
	     'target_taxon_id' => $target_taxon_id,
	     'target_external_db_release_id' => $target_external_db_release_id,
	     'is_consistent' => $is_consistent,
	     'is_genomic_contaminant' => $is_genomic_contaminant,
	     'unaligned_3p_bases' => $unaligned_3p_bases,
	     'unaligned_5p_bases' => $unaligned_5p_bases,
	     'has_3p_polya' => $has_3p_polya,
	     'has_5p_polya' => $has_5p_polya,
	     'is_3p_complete' => $is_3p_complete,
	     'is_5p_complete' => $is_5p_complete,
	     'percent_identity' => $percent_identity,
	     'max_query_gap' => $max_query_gap,
	     'max_target_gap' => $max_target_gap,
	     'number_of_spans' => $number_of_spans,
	     'query_start' => $query_start,
	     'query_end' => $query_end,
	     'target_start' => $virtual_target_start,
	     'target_end' => $virtual_target_end,
	     'is_reversed' => $is_reversed,
	     'query_bases_aligned' => $query_bases_aligned,
	     'repeat_bases_aligned' => $repeat_bases_aligned,
	     'num_ns' => $num_ns,
	     'score' => $score,
	     'is_best_alignment' => $is_best_alignment,
	     'blat_alignment_quality_id' => $blat_alignment_quality_id,
	     'blocksizes' => $blocksizes,
	     'qstarts' => $qstarts,
	     'tstarts' => $virtual_tstarts,
	    });
    $ba->submit();

    $recordCount++;
    unless ($recordCount % 1000) {
      warn "Processed $recordCount records";
      $self->undefPointerCache();
    }
  }

  warn "Processed $recordCount records";
  $self->undefPointerCache();
  $queryHandle->finish();
}

sub getReversedTstarts {
  my($dfl,$len,$tstart,$blocksizes) = @_;
  my @ts = split(',',$tstart);
  my @bs = split(',',$blocksizes);
  my @new;

  for(my $a = scalar(@ts) - 1;$a >= 0;$a--){
    push(@new,($dfl + $len - $ts[$a] - $bs[$a] + 2));
  }
  return join(',',@new);
}


sub undoTables {
  return qw(DoTS.BLATAlignment
           );
}
