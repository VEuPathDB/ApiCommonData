
#vvvvvvvvvvvvvvvvvvvvvvvvv GUS4_STATUS vvvvvvvvvvvvvvvvvvvvvvvvv
  # GUS4_STATUS | SRes.OntologyTerm              | auto   | absent
  # GUS4_STATUS | SRes.SequenceOntology          | auto   | absent
  # GUS4_STATUS | Study.OntologyEntry            | auto   | absent
  # GUS4_STATUS | SRes.GOTerm                    | auto   | absent
  # GUS4_STATUS | Dots.RNAFeatureExon            | auto   | absent
  # GUS4_STATUS | RAD.SageTag                    | auto   | absent
  # GUS4_STATUS | RAD.Analysis                   | auto   | absent
  # GUS4_STATUS | ApiDB.Profile                  | auto   | absent
  # GUS4_STATUS | Study.Study                    | auto   | absent
  # GUS4_STATUS | Dots.Isolate                   | auto   | absent
  # GUS4_STATUS | DeprecatedTables               | auto   | absent
  # GUS4_STATUS | Pathway                        | auto   | absent
  # GUS4_STATUS | DoTS.SequenceVariation         | auto   | absent
  # GUS4_STATUS | RNASeq Junctions               | auto   | absent
  # GUS4_STATUS | Simple Rename                  | auto   | absent
  # GUS4_STATUS | ApiDB Tuning Gene              | auto   | absent
  # GUS4_STATUS | Rethink                        | auto   | absent
  # GUS4_STATUS | dots.gene                      | manual | reviewed
#^^^^^^^^^^^^^^^^^^^^^^^^^ End GUS4_STATUS ^^^^^^^^^^^^^^^^^^^^
package ApiCommonData::Load::Plugin::LoadBLATProteinAlignments; 

# ----------------------------------------------------------------------
# LoadBLATProteinAlignments.pm
#
# Load a set of BLAT alignments into GUS.  Assumes that the 
# query sequences are identified with GUS na_sequence_ids.  The
# subject (genomic) sequences may use either na_sequence_ids
# or source_ids (if the corresponding external_db_id is given).
#
# Created: Sun Apr 28 22:48:04 EDT 2002
#
# Jonathan Crabtree
#
# $Revision$ $Date$ $Author$
# ----------------------------------------------------------------------

# ========================================================================
# ----------------------------- Declarations -----------------------------
# ========================================================================

use strict;
use vars qw( @ISA );

@ISA = qw(GUS::PluginMgr::Plugin); 

use Data::Dumper;

use CBIL::Bio::BLAT::PSL;
use CBIL::Bio::BLAT::PSLDir;
use CBIL::Bio::BLAT::Alignment;
use CBIL::Bio::FastaIndex;
use CBIL::Util::TO;
use CBIL::Util::Disp;
use GUS::PluginMgr::Plugin;
use FileHandle;

use ApiCommonData::Load::AlignmentFileReader;

# ========================================================================
# --------------------------- Global Variables ---------------------------
# ========================================================================

my $VERSION = '$Revision$'; $VERSION =~ s/Revision://; $VERSION =~ s/\$//g; $VERSION =~ s/ //g; #'

my $TPREF = 'DoTS';
my $BLATSCHEMA = 'ApiDB';

my $purposeBrief = <<PURPOSEBRIEF;
Load a set of BLAT alignments into GUS.
PURPOSEBRIEF

my $purpose = <<PLUGIN_PURPOSE;
Load a set of BLAT alignments into GUS.  Assumes that the query sequences are identified with GUS na_sequence_ids.  The subject (genomic) sequences may use either na_sequence_ids or source_ids (if the corresponding external_db_id is given)
PLUGIN_PURPOSE

#check the documentation for this
my $tablesAffected = [
                      ['$BLATSCHEMA::BlatProteinAlignment', '']
                     ];

my $tablesDependedOn = [
                       ];

my $howToRestart = <<PLUGIN_RESTART;
PLUGIN_RESTART

my $failureCases = <<PLUGIN_FAILURE_CASES;
PLUGIN_FAILURE_CASES

my $notes = <<PLUGIN_NOTES;
PLUGIN_NOTES

my $documentation = {
                     purposeBrief => $purposeBrief,
                     purpose => $purpose,
                     tablesAffected => $tablesAffected,
                     tablesDependedOn => $tablesDependedOn,
                     howToRestart => $howToRestart,
                     failureCases => $failureCases,
                     notes => $notes
                    };

my $argsDeclaration = [
                       stringArg({
                                  name => 'action',
                                  descr => 'one of: strip, get rid of extra psl headers; load, get alignments into db; setbest: set best alignment status, maybe delete unwanted alignments. Do all above if not set',
                                  constraintFunc=> undef,
                                  reqd  => 0,
                                  isList => 0,
                                  constraintFunc=> undef,
                                  reqd  => 0,
                                  isList => 0
                                 }),
                       stringArg({
                                  name => 'blat_dir',
                                  descr => 'dir with files containing BLAT results in .psl format',
                                  constraintFunc=> undef,
                                  reqd  => 0,
                                  isList => 0,
                                 }),
                       stringArg({
                                  name => 'blat_files',
                                  descr => 'Files containing BLAT results in .psl format',
                                  constraintFunc=> undef,
                                  reqd  => 0,
                                  isList => 0,
                                 }),
                       stringArg({ 
                                  name => 'file_list',
                                  descr => 'File that contains a list of newline-separated BLAT files (used instead of --blat_files).',
                                  constraintFunc=> undef,
                                  reqd  => 0,
                                  isList => 0,
                                 }),
                       stringArg({
                                  name => 'query_file',
                                  descr => 'FASTA file that contains all of the BLAT query sequences.',
                                  constraintFunc=> undef,
                                  reqd  => 1,
                                  isList => 0,
                                 }),
                       integerArg({
                                   name => 'keep_best',
                                   descr => 'keep how many alignments per query? (1: 1, 2: top 1%,3: all top, o.w. all)',
                                   constraintFunc=> undef,
                                   reqd  => 0,
                                   isList => 0,
                                  }),
		       integerArg({
                                   name => 'percentTop',
                                   descr => 'set is_best to 1 for scores that are this percent of the top, e.g. 100 = only the top,otherwise 99',
                                   constraintFunc=> undef,
                                   reqd  => 0,
                                   isList => 0,
                                  }),
                       stringArg({
                                  name => 'gap_table_space',
                                  descr => 'table space where genomic gap info is stored',
                                  constraintFunc=> undef,
                                  reqd  => 0,
                                  isList => 0,
                                 }),
                       stringArg({
                                  name => 'previous_runs',
                                  descr => 'Comma-separated list of algorithm_invocation_ids of previous runs; any duplicate results from these runs are ignored.',
                                  constraintFunc=> undef,
                                  reqd  => 0,
                                  isList => 0,
                                 }),
                       integerArg({
                                   name => 'report_interval',
                                   descr => 'Print a progress message every report_interval entries processed',
                                   default => 5000,
                                   constraintFunc=> undef,
                                   reqd  => 0,
                                   isList => 0,
                                  }),
                       integerArg({
                                   name => 'commit_interval',
                                   descr => 'Commit after this number of entries have been inserted.',
                                   default => 500,
                                   constraintFunc=> undef,
                                   reqd  => 0,
                                   isList => 0,
                                  }),
                       #####################################
                       # BLAT run identification parameters
                       #####################################
                       integerArg({
                                   name => 'query_table_id',
                                   descr => 'GUS table_id for the NASequence view that contains the BLAT query sequences.',
                                   default => 56,
                                   constraintFunc=> undef,
                                   reqd  => 0,
                                   isList => 0,
                                  }),
                       integerArg({
                                   name => 'query_taxon_id',
                                   descr => 'GUS taxon_id for the BLAT query sequences.',
                                   constraintFunc=> undef,
                                   reqd  => 0,
                                   isList => 0,
                                  }),
                       integerArg({
                                   name => 'query_db_rel_id',
                                   descr => 'GUS external_db_release_id for the BLAT query sequence',
                                   constraintFunc=> undef,
                                   reqd  => 0,
                                   isList => 0,
                                  }),
                       integerArg({
                                   name => 'target_table_id',
                                   descr => 'GUS table_id for the NASequence view that contains the BLAT target sequences.',
                                   default => 245, # VirtualSequence
                                   constraintFunc=> undef,
                                   reqd  => 0,
                                   isList => 0,
                                  }),
                       integerArg({
                                   name => 'target_taxon_id',
                                   descr => 'GUS taxon_id for the BLAT target sequences.',
                                   constraintFunc=> undef,
                                   reqd  => 0,
                                   isList => 0,
                                  }),
                       # 4792 = UCSC/NCBI 12/22/2001 release (human)
                       # 5093 = UCSC Mm virtual chromosomes (February 2002 release)
                       #
                       integerArg({
                                   name => 'target_db_rel_id',
                                   descr => 'GUS external_db_release_id for the BLAT target sequences (only required if using source_ids for target.)',
                                   constraintFunc=> undef,
                                   reqd  => 0,
                                   isList => 0,
                                  }),
                       booleanArg({
                                   name => 'target_has_na_sequence_ids',
                                   descr => 'Target sequences are identified by na_sequence_id. The default expects target source_ids which will be mapped to na_sequence_ids.)',
                                   constraintFunc=> undef,
                                   reqd  => 0,
                                   isList => 0,
                                  }),
                       ######################################################
                       # gate-keeping parameter to prevent loading everything
                       ######################################################
                       integerArg({
                                   name => 'min_query_pct',
                                   descr => 'Minimum percentage of the query sequence that must align in order for an alignment to be loaded.',
                                   default => 10,
                                   constraintFunc=> undef,
                                   reqd  => 0,
                                   isList => 0,
                                  }),
                       ##################################################
                       # parameters for blat alignment quality assessment
                       ##################################################
                       integerArg({
                                   name => 'max_end_mismatch',
                                   descr => 'Maximum mismatch, excluding polyA, at either end of the query sequence for a consistent alignment.',
                                   default => 10,
                                   constraintFunc=> undef,
                                   reqd  => 0,
                                   isList => 0,
                                  }),
                       integerArg({
                                   name => 'min_pct_id',
                                   descr => 'Minimum percent identity for a consistent alignment.',
                                   default => 95,
                                   constraintFunc=> undef,
                                   reqd  => 0,
                                   isList => 0,
                                  }),
                       integerArg({
                                   name => 'max_query_gap',
                                   descr => 'Maximum size gap (unaligned segment) in the query sequence for a consistent alignment.',
                                   default => 5,
                                   constraintFunc=> undef,
                                   reqd  => 0,
                                   isList => 0,
                                  }),
                       integerArg({
                                   name => 'ok_internal_gap',
                                   descr => 'Tolerated size of internal gap (unaligned segment) in the query sequence for a alignment quality assessment.',
                                   default => 15,
                                   constraintFunc=> undef,
                                   reqd  => 0,
                                   isList => 0,
                                  }),
                       integerArg({
                                   name => 'ok_end_gap',
                                   descr => 'Tolerated size of end gap (unaligned segment) in the query sequence for a alignment quality assessment.',
                                   default => 50,
                                   constraintFunc=> undef,
                                   reqd  => 0,
                                   isList => 0,
                                  }),
                       integerArg({
                                   name => 'end_gap_factor',
                                   descr => 'multiplication factor to be applied to the size of query end mismatch for the search of genomic gaps',
                                   default => 10,
                                   constraintFunc=> undef,
                                   reqd  => 0,
                                   isList => 0,
                                  }),
                       integerArg({
                                   name => 'min_gap_pct',
                                   descr => 'minimum size percentage of a genomic gap that seems to correspond to a query gap',
                                   default => 90,
                                   constraintFunc=> undef,
                                   reqd  => 0,
                                   isList => 0,
                                  }),
                       stringArg({
                                  name => 'queryRegex',
                                  descr => 'regex used to extract identifier for query sequences from defline',
                                  constraintFunc=> undef,
                                  reqd  => 1,
                                  isList => 0,
                                 }),
                      ];


	

# PSL lines represent alignments, and are typically taken from files generated by BLAT or psLayout. All of the following fields are required on each data line within a PSL file:

#     1. matches - Number of bases that match that aren't repeats
#     2. misMatches - Number of bases that don't match
#     3. repMatches - Number of bases that match but are part of repeats
#     4. nCount - Number of 'N' bases
#     5. qNumInsert - Number of inserts in query
#     6. qBaseInsert - Number of bases inserted in query
#     7. tNumInsert - Number of inserts in target
#     8. tBaseInsert - Number of bases inserted in target
#     9. strand - '+' or '-' for query strand. For translated alignments, second '+'or '-' is for genomic strand
#     10. qName - Query sequence name
#     11. qSize - Query sequence size
#     12. qStart - Alignment start position in query
#     13. qEnd - Alignment end position in query
#     14. tName - Target sequence name
#     15. tSize - Target sequence size
#     16. tStart - Alignment start position in target
#     17. tEnd - Alignment end position in target
#     18. blockCount - Number of blocks in the alignment (a block contains no gaps)
#     19. blockSizes - Comma-separated list of sizes of each block
#     20. qStarts - Comma-separated list of starting positions of each block in query
#     21. tStarts - Comma-separated list of starting positions of each block in target 




# ========================================================================
# ----------------------------- Main Methods -----------------------------
# ========================================================================

# --------------------------------- new ----------------------------------

sub new {
   my ($class) = @_;
   my $self    = {};
   bless($self,$class);

   $self->initialize({requiredDbVersion => 4.0,
                      cvsRevision => '$Revision$', # cvs fills this in!
                      name => ref($self),
                      argsDeclaration => $argsDeclaration,
                      documentation => $documentation
                     });
   return $self;
}

# --------------------------------- run ----------------------------------

sub run {
   my $self = shift;
   $| = 1;

   my $blatDir       = $self->getArg('blat_dir');
   my $blatFiles     = $self->getArg('blat_files');
   my $fileList      = $self->getArg('file_list');
   my $queryFile     = $self->getArg('query_file');
   my $queryTableId  = $self->getArg('query_table_id');
   my $targetTableId = $self->getArg('target_table_id');
   my $action        = $self->getArg('action');
   my $dbh           = $self->getQueryHandle();

   my $queryTableName = $self->getTableNameFromTableId($dbh, $queryTableId);
   die "LoadBLATProteinAlignments: query_file not defined" unless (-e $queryFile);
   die "LoadBLATProteinAlignments: unrecognized query_table_id"  unless $queryTableName =~ /^(?:AASequence|ExternalAASequence|Assembly|AssemblySequence|ExternalNASequence|VirtualSequence|SplicedNASequence)$/i;
   die "LoadBLATProteinAlignments: unrecognized target_table_id" unless ($self->getTableNameFromTableId($dbh, $targetTableId) =~ /^(?:Assembly|AssemblySequence|ExternalNASequence|VirtualSequence|SplicedNASequence)$/i);

 
   my $summary;

   my @blatFiles = $self->getBlatFiles($blatDir, $blatFiles, $fileList) unless $action eq 'setbest';

   if (!$action || $action eq 'strip') {
      foreach my $file (@blatFiles) {
         $self->log("stripping extra headers in $file");
         &CBIL::Bio::BLAT::PSLDir::strip($file);
      }
   }

   if (!$action || $action eq 'load') {
      my $emptyBlatFiles=0;
      foreach my $file (@blatFiles) {
      if(-z $file){
	  $self->log("$file is empty.");
	  $emptyBlatFiles++;
	  }
      }
      die "LoadBLATProteinAlignments: all blat files are empty" if ($emptyBlatFiles == scalar(@blatFiles));
      my $blatFiles = join(',', @blatFiles);
      $self->log("Load alignments from raw BLAT output files $blatFiles ...");
      my $qIndex;
      $qIndex = $self->maybeIndexQueryFile($queryFile) unless $queryTableName =~ /AASequence$/i;
      $summary = $self->loadAlignments($blatFiles, $qIndex);
   }

   if (!$action || $action eq 'setbest') {
      $self->log("setting best alignment status, maybe remove unwanted entries...");
      $summary .= $self->keepBestAlignments;
   }

   return $summary;
}

# ========================================================================
# --------------------------- Support Methods ----------------------------
# ========================================================================


sub flagAlignmentsForKeep {
  my ($self, $featuresArrayRef, $positions) = @_;

  my @features = @$featuresArrayRef;

  my @sortedPositions = sort {$a <=> $b} keys(%$positions);

  for(my $i = 0; $i < scalar(@sortedPositions)-1; $i++) {

    my $loc = $sortedPositions[$i];

    my $index = 0;
    my @keep;

    while(1) {
      last unless($features[$index]);

      if($features[$index]->{start} > $loc) {
        last;
      }
      
      if($features[$index]->{end} >= $loc) {
        push @keep, $features[$index];
      }
      
      if($features[$index]->{end} < $loc) {
        splice(@features, $index, 1);
      }
      else {
        $index++; 
      }
    }

    my @expanded;
    foreach(@keep) {
      push @expanded, @{$_->{_alignments}};
    }

    my @sorted = sort {$b->getScore() <=> $a->getScore() || $b->getAlignedBases() <=> $a->getAlignedBases() } @expanded;

    my $count = 1;
    foreach(@sorted) {
      $_->{_keep} = 1;

      $count++;
      last if($count > 10);
    }
  }

}


sub compressAlignments {
  my ($self, $sortedAlignments) = @_;

  my @features;
  my %positions;

  my ($prevStart, $prevEnd, $prevFeature);
  my $bAlignCt;

  foreach my $align (@$sortedAlignments) {
    my $start = $align->get('t_start');
    my $end = $align->get('t_end');
    my $score = $align->getScore();
    my $basesAligned = $align->getAlignedBases();
    
    next if(($end - $start) > 5000);

    if($start == $prevStart && $end == $prevEnd) {
      next if($bAlignCt++ > 10);

      push @{$prevFeature->{_alignments}}, $align;
      next;
    } 

    $bAlignCt = 1;

    my $feature = {start => $start, 
                   end => $end,
    };

    push @{$feature->{_alignments}}, $align;

    push @features, $feature;

    $positions{$start}++;
    $positions{$end+1}++; # need a +1 on the end position

    $prevStart = $start;
    $prevEnd = $end;
    $prevFeature = $feature;
  }

  return \@features, \%positions;
}




# ---------------------------- loadAlignments ----------------------------

sub loadAlignments {
   my ($self, $blatFiles, $qIndex) = @_;
    
   my $dbh = $self->getQueryHandle();

   my $reportInterval = $self->getArg('report_interval');
   my $commitInterval = $self->getArg('commit_interval');
   my $prevRuns = $self->getArg('previous_runs');

   my $queryTableId = $self->getArg('query_table_id');
   my $queryTaxonId = $self->getArg('query_taxon_id');
   my $queryExtDbRelId = $self->getArg('query_db_rel_id');
   my $targetTableId = $self->getArg('target_table_id');
   my $targetTaxonId = $self->getArg('target_taxon_id');
   my $targetExtDbRelId = $self->getArg('target_db_rel_id');
   my $gapTabSpace = $self->getArg('gap_table_space');
   my $gapTabPref;
   if ($gapTabSpace) {
      my $ext_genome_ver = $self->getGenomeVersion($dbh, $targetExtDbRelId);
      $gapTabPref = "${gapTabSpace}.${ext_genome_ver}_";
   }

   my $minQueryPct = $self->getArg('min_query_pct');

   # Parameters used to assess alignments qualities
   #
   my $qualityParams = {
                        'maxEndMismatch' => $self->getArg('max_end_mismatch'),
                        'minPctId' => $self->getArg('min_pct_id'),
                        'maxQueryGap' => $self->getArg('max_query_gap'),
                        'okInternalGap' => $self->getArg('ok_internal_gap'),
                        'okEndGap' => $self->getArg('ok_end_gap'),
                        'endGapFactor' => $self->getArg('end_gap_factor'),
                        'minGapPct' => $self->getArg('min_gap_pct'),
                       };

   my @prevAlgInvIds = defined($prevRuns) ? split(/,|\s+/, $prevRuns): ();

   # 1. Read target source ids if requested
   #
   my $targetTable = $self->getTableNameFromTableId($dbh, $targetTableId);
   my $targetIdHash = ($targetExtDbRelId =~ /\d+/) ?
   $self->makeSourceIdHash($dbh, "$TPREF.$targetTable", $targetExtDbRelId) : undef;

   # 2. Build hash of alignments that have already been loaded; we assume
   #    that an alignment can be uniquely identified by its coordinates.
   #
   my $alreadyLoaded = $self->makeAlignmentHash($dbh, \@prevAlgInvIds, $queryTableId, $targetTableId);

   # 3. Load BLAT alignments into BLATProteinAlignment
   #
   my @files      = split(/,|\s+/, $blatFiles);
   my $nFiles     = scalar(@files);

   my $userId     = $self->getDb()->getDefaultUserId();
   my $groupId    = $self->getDb()->getDefaultGroupId(); 
   my $projectId  = $self->getDb()->getDefaultProjectId();
   my $algInvId   = $self->getAlgInvocation()->getId();

   my $nextvalVar = $self->getDb()->getDbPlatform()->nextVal("$BLATSCHEMA.BLATProteinAlignment");

   my $insertSql  = ("INSERT INTO $BLATSCHEMA.BLATProteinAlignment VALUES (" .
                     "$nextvalVar, " .
                     "?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, " .
                     "?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, " .
                     "SYSDATE, 1, 1, 1, 1, 1, 0, " .
                     "$userId, $groupId, $projectId, $algInvId)");
   #print STDERR "LoadBLATProteinAlignments: insert sql = '$insertSql'\n";

   my $sth = $dbh->prepare($insertSql);

   my $nTotalAligns = 0;
   my $nTotalAlignsLoaded = 0;

   my $queryTableName = lc($self->getTableNameFromTableId($dbh, $queryTableId));

   foreach my $blatFile (@files) {
      print "LoadBLATProteinAlignments: reading from $blatFile\n";

      my $nAligns = 0;
      my $nAlignsLoaded = 0;

      my $reader = ApiCommonData::Load::AlignmentFileReader->new($blatFile, undef, "\t");

      while($reader->hasNext()) {
        my $alignments = $reader->readNextGroupOfLines();
        
        my @sortedAlignments = sort { 
          $a->get('t_start') <=> $b->get('t_start') 
              || $a->get('t_end') <=> $b->get('t_end') 
              || $b->getScore() <=> $a->getScore() 
              || $b->getAlignedBases() <=> $a->getAlignedBases()
        } @$alignments;

        my ($features, $positions) = $self->compressAlignments(\@sortedAlignments);

        $self->flagAlignmentsForKeep($features, $positions);        

        foreach my $align (@$alignments) {
          next unless($align->{_keep}); #flagAlignmentsForKeep sets this

          ++$nAligns;
          ++$nTotalAligns;

          my $gapTab = ($gapTabPref ? "${gapTabPref}" . $align->get('t_name') . "_gap" : "");
          my $nl = $self->loadAlignment($dbh, $gapTab, $insertSql, $sth, $queryTableId, $queryTaxonId,
                                        $queryExtDbRelId, $targetTableId, $targetTaxonId, $targetExtDbRelId,
                                        $qIndex, $qualityParams, $alreadyLoaded, $targetIdHash, $align,
                                        $minQueryPct, $queryTableName);
          
          $nAlignsLoaded += $nl;
          $nTotalAlignsLoaded += $nl;

          $self->progressMessage($reportInterval, $nTotalAligns, 'BLAT alignments processed.');
          $self->progressMessage($reportInterval, $nTotalAlignsLoaded, 'BLAT alignments loaded.') if ($nl > 0);

          $dbh->commit() if (($nTotalAlignsLoaded % $commitInterval) == 0 && $self->getArg('commit'));
        }
      }


      $dbh->commit() if $self->getArg('commit');

      print "LoadBLATProteinAlignments: loaded $nAlignsLoaded/$nAligns BLAT alignments from $blatFile.\n";


   }

   my $summary = "Loaded $nTotalAlignsLoaded/$nTotalAligns BLAT alignments from $nFiles file(s).\n";
   print "LoadBLATProteinAlignments: ", $summary, "\n";
   return $summary;
}

# -------------------------- getAlignmentGroups --------------------------
sub getBlatAlignmentIds {
  my ($self) = @_;

  my $dbh = $self->getQueryHandle();

  my $queryTableId = $self->getArg('query_table_id');
  my $queryTaxonId = $self->getArg('query_taxon_id');
  my $queryExtDbRelId = $self->getArg('query_db_rel_id');
  my $targetTableId = $self->getArg('target_table_id');
  my $targetTaxonId = $self->getArg('target_taxon_id');
  my $targetExtDbRelId = $self->getArg('target_db_rel_id');

   my $sql = "select distinct (query_aa_sequence_id) "
   . "from $BLATSCHEMA.BlatProteinAlignment "
   . "where query_table_id = $queryTableId "
   . ($queryTaxonId ? "and query_taxon_id = $queryTaxonId " : "")
   . ($queryExtDbRelId ? "and query_external_db_release_id = $queryExtDbRelId " : "")
   . "and target_table_id = $targetTableId "
   . "and target_taxon_id = $targetTaxonId "
   . "and target_external_db_release_id = $targetExtDbRelId";
   my $sth = $dbh->prepare($sql) or die "bad sql $sql:!\n";
   $self->logVerbose("# running $sql...");
   $sth->execute or die "could not run $sql: $!";

  my @blatIds;
  while (my ($id) = $sth->fetchrow_array) {
    push (@blatIds, $id);
  }
  $sth->finish;

  \@blatIds;
}

sub getAlignmentGroups {
   my ($self, $queryId) = @_;

   my $dbh = $self->getQueryHandle();

   my $queryTableId = $self->getArg('query_table_id');
   my $queryTaxonId = $self->getArg('query_taxon_id');
   my $queryExtDbRelId = $self->getArg('query_db_rel_id');
   my $targetTableId = $self->getArg('target_table_id');
   my $targetTaxonId = $self->getArg('target_taxon_id');
   my $targetExtDbRelId = $self->getArg('target_db_rel_id');

   my $sql = "select query_aa_sequence_id, blat_alignment_id, score, percent_identity "
   . "from $BLATSCHEMA.BlatProteinAlignment "
   . "where query_table_id = $queryTableId "
   . ($queryTaxonId ? "and query_taxon_id = $queryTaxonId " : "")
   . ($queryExtDbRelId ? "and query_external_db_release_id = $queryExtDbRelId " : "")
   . "and target_table_id = $targetTableId "
   . "and target_taxon_id = $targetTaxonId "
   . "and target_external_db_release_id = $targetExtDbRelId and query_aa_sequence_id = $queryId";
   my $sth = $dbh->prepare($sql) or die "bad sql $sql:!\n";
   $self->logVerbose("# running $sql...");
   $sth->execute or die "could not run $sql: $!";

   my %alnGrps;
   while (my ($sid, $bid, $score, $pct_id) = $sth->fetchrow_array) {
      $alnGrps{$sid} = [] unless $alnGrps{$sid};
      push @{ $alnGrps{$sid} }, [$bid, $score, $pct_id];
   }
   $sth->finish;

   \%alnGrps;
}

# -------------------------- keepBestAlignments --------------------------

sub keepBestAlignments {
   my ($self) = @_;

   my $dbh = $self->getQueryHandle();

   my $keepBest = $self->getArg('keep_best');
   my $queryTableId = $self->getArg('query_table_id');
   my $queryTaxonId = $self->getArg('query_taxon_id');
   my $queryExtDbRelId = $self->getArg('query_db_rel_id');
   my $targetTableId = $self->getArg('target_table_id');
   my $targetTaxonId = $self->getArg('target_taxon_id');
   my $targetExtDbRelId = $self->getArg('target_db_rel_id');
   my $commitInterval = $self->getArg('commit_interval');
   my $percentTop = $self->getArg('percentTop') ? $self->getArg('percentTop') / 100 : 0.99;
   # get alignment groups by query
   #
   print "# grouping alignments by query (DT)...\n";
   my $blatIds = $self->getBlatAlignmentIds();

   # process result
   #
   print "# setting is_best_alignment status for each group...\n";
   my $tot_sq = @$blatIds;
   my ($tot_al, $tot_bs) = (0,0);

   foreach my $sid (@$blatIds) {
     $dbh->do("update $BLATSCHEMA.BlatProteinAlignment set is_best_alignment = 0 "
		  . "where blat_alignment_id = $sid and is_best_alignment != 0" );
   }
   $dbh->commit() if $self->getArg('commit');

   foreach my $sid (@$blatIds) {
     my $alnGrps = $self->getAlignmentGroups($sid);
     my @oneGrp = @{ $alnGrps->{$sid} };
     my $grpSize = scalar(@oneGrp);

     my $best_score = 0;
     foreach (@oneGrp) {
       my ($bid, $score, $pct_id) = @$_;
       $best_score = $score if $score > $best_score;
       $tot_al++;
     }
     foreach (@oneGrp) {
       my ($bid, $score, $pct_id) = @$_;

       my $is_best = ($grpSize == 1 || $score >= $percentTop * $best_score);
       if ($is_best) {
	 $tot_bs++;
	 $dbh->do("update $BLATSCHEMA.BlatProteinAlignment set is_best_alignment = 1 "
		  . "where blat_alignment_id = $bid" );
	 if (($tot_bs % $commitInterval) == 0) {
	   $dbh->commit() if $self->getArg('commit');
	   print "# $tot_bs alignments marked is_best_alignment = 1\n";
	 }
       }
     }
     $dbh->commit() if $self->getArg('commit');
   }

   @$blatIds = ();

   my $summary = "$tot_sq DoTS with $tot_al ($tot_bs) alignments (that are bests)\n";
   print $summary;

   if ($keepBest == 1) {
      print "# TODO: keep only one alignment per query\n";
   } elsif ($keepBest == 2) {
      print "deleting non-top alignments ...\n";
      my $sql = "delete $BLATSCHEMA.BlatProteinAlignment "
      . "where query_table_id = $queryTableId "
      . ($queryTaxonId ? "and query_taxon_id = $queryTaxonId " : "")
      . "and target_table_id = $targetTableId "
      . "and target_taxon_id = $targetTaxonId "
      . "and target_external_db_release_id = $targetExtDbRelId "
      . "and (is_best_alignment is null or is_best_alignment = 0)";
      $dbh->do($sql) or die "could not run $sql:!\n";
      $dbh->commit() if $self->getArg('commit');
      $summary .= "(non-best alignments deleted from db)\n";
   }

   return $summary;
}

#-------------------------------------------------
# Subroutines
#-------------------------------------------------

# maybe index query sequence file
#
sub maybeIndexQueryFile {
   my ($self,$queryFile) = @_;
   # Make sure that query_file is indexed
   #
   my $qIndex = new CBIL::Bio::FastaIndex(CBIL::Util::TO->new({seq_file => $queryFile, open => 1}));

   if (!$qIndex->open()) {
      my $regex = $self->getArg('queryRegex');
      my $idSub = sub {
         my($defline) = @_;

         if ($defline =~ /$regex/) {
            return $1;
         }

         $self->error ("Unable to parse $defline with regex = '$regex'");
      };
      $qIndex->createIndex(CBIL::Util::TO->new({get_key => $idSub}));
      $qIndex = undef;
      $qIndex = new CBIL::Bio::FastaIndex(CBIL::Util::TO->new({seq_file => $queryFile, open => 1}));
   }
   $qIndex;
}

sub getBlatFiles {
   my ($self,$blatDir, $blatFiles, $fileList) = @_;
   die "LoadBLATProteinAlignments: blat files not defined" unless $blatDir || $blatFiles || $fileList;

   return split(/,/, $blatFiles) if $blatFiles;

   # Read list of files if need be
   #
   my @files;
   if ($fileList && !$blatFiles) {
      my $fl = `cat $fileList`;
      @files = split(/[\s\n]+/,$fl);
   }

   if ($blatDir && !$blatFiles) {
      my $bd = CBIL::Bio::BLAT::PSLDir->new($blatDir);
      @files = $bd->getPSLFiles;
   }

   @files;
}

# Print a progress message if appropriate
#
sub progressMessage {
   my($self,$interval, $num, $what) = @_;

   return if (not defined($interval));
   return if ($num == 0);

   if (($interval < 0) || ($num % $interval == 0)) {
      my $date = `date`;
      chomp($date);
      print "LoadBLATProteinAlignments: $date $num $what\n";
   }
}

# Return the name of a table given its GUS table_id.
#
sub getTableNameFromTableId {
   my($self,$dbh, $tid) = @_;

   my $sth = $dbh->prepareAndExecute("select distinct name from core.TableInfo where table_id = $tid");
   my($name) =  $sth->fetchrow_array();
   $sth->finish();

   return $name;
}

# Create a hash mapping source_id to na_sequence_id, if the
# user has supplied an external_db_id for the target sequences.
#
sub makeSourceIdHash {
   my($self,$dbh, $targetTable, $targetDbId) = @_;
   my $hash = {};

   my $sql = ("select source_id, na_sequence_id " .
              "from $targetTable " .
              "where external_database_release_id = $targetDbId");

   my $sth = $dbh->prepare($sql);

   $sth->execute();
   while (my @a = $sth->fetchrow_array()) {
      my $v = $hash->{$a[0]};
      if (defined($v)) {
         print STDERR "LoadBLATProteinAlignments: WARNING - duplicate source_id $a[0] in $targetTable\n";
      } else {
         $hash->{$a[0]} = $a[1];
      }
   }
   $sth->finish();

   print STDERR "LoadBLATProteinAlignments: read ", scalar(keys %$hash), " source_ids for ";
   print STDERR "external_db_release_id $targetDbId from $targetTable.\n";

   return $hash;
}

# Create a hash containing all the BLAT alignments already in the 
# database for a given set of row_alg_invocation_id's.  Assumes
# that the two sequence ids + the alignment coordinates are a unique
# identifier.
#
sub makeAlignmentHash {
   my($self,$dbh, $algInvIds, $queryTableId, $targetTableId) = @_;

   print STDERR "LoadBLATProteinAlignments: Building hash using alg_inv_ids: [", join(", ", @$algInvIds), "]\n";

   my $hash = {};
   return $hash if (scalar(@$algInvIds) == 0);

   my $sql = (
              "select query_aa_sequence_id, target_na_sequence_id, " .
              "       query_start, query_end, target_start, target_end " .
              "from $BLATSCHEMA.BLATProteinAlignment " .
              "where row_alg_invocation_id in ( " . join(",", @$algInvIds) . " )"
             );

   print STDERR "LoadBLATProteinAlignments: running '$sql'\n";

   my $sth = $dbh->prepare($sql);
   $sth->execute();

   my $nRows = 0;

   while (my @a = $sth->fetchrow_array()) {
      my $key = join(":", @a);
      my $entry = $hash->{$key};

      if (defined($entry)) {
         print STDERR "LoadBLATProteinAlignments: WARNING - already seen an alignment for $key\n";
      } else {
         $hash->{$key} = 1;
      }
      ++$nRows;
   }

   $sth->finish();

   print STDERR "LoadBLATProteinAlignments.makeAlignmentHash: Entered $nRows rows into hash\n";
   return $hash;
}

# ---------------------------- loadAlignment -----------------------------

=pod

=head1 Loading a BLAT Alignment

When loading a single BLAT alignment into the GUS BLATProteinAlignment table,
C<loadAlignment> checks if it is not already present in $alreadyLoaded
and it meets the minimum query percent alignment cutoff.  Returns the
number of alignments (0 or 1) actually loaded.

=cut

sub loadAlignment {
   my ($self,$dbh, $gapTable, $sql, $sth, $queryTableId, $queryTaxonId, $queryExtDbRelId,
       $targetTableId, $targetTaxonId, $targetExtDbRelId,$qIndex, $qualityParams,
      $alreadyLoaded, $targetIdHash, $align, $minQueryPct, $queryTableName) = @_;

   my $query_id  = $align->get('q_name');
   my $target_id = $align->get('t_name');

   ## if the $query_id matches the query_regex then use this to pull out the proper identifier
   ## used for the nrdb vs genome blatx
   my $queryRegex = $self->getArg('queryRegex');
   $query_id = $query_id =~ /$queryRegex/ ? $1 : $query_id;

   # Map target query name -> na_sequence_id if required
   #
   if (defined($targetIdHash)) {
      my $srcId = $target_id;
      $target_id = $targetIdHash->{$srcId};

      if (!($target_id =~ /\d+/)) {
         die "LoadBLATProteinALignments: ERROR - unable to resolve target source_id '$srcId'\n";
      }
   }

   # Convert external na seq source id to seq id, convert 'DT.blah' to 'blah' 
   #
   my $origQueryId = $query_id;
   # HACK
   $query_id = $self->getQueryNaSeqId($dbh, $query_id, $queryTableName);
   unless($query_id){
      print STDERR "LoadBLATProteinAlignments: Can not find query_id\n";
      return 0; 
   }
   $query_id =~ s/[^0-9]//g;  ##this seems VERY odd ... the identifier is an integer so wouldn't this make it null?

   # Check to see whether this alignment has already been loaded
   #
   my $qs = $align->get('q_start'); my $qe = $align->get('q_end');
   my $ts = $align->get('t_start'); my $te = $align->get('t_end');

   my $key    = join(":", ($query_id, $target_id, $qs, $qe, $ts, $te));
   my $loaded = $alreadyLoaded->{$key};

   if ($loaded == 1) {
      print STDERR "LoadBLATProteinAlignments: Already loaded alignment of $query_id vs $target_id\n";
      return 0;
   }

   # Check to see whether this alignment meets the $minQueryPct cutoff
   #
   my $qSize        = $align->get('q_size');
   my $matches      = $align->get('matches');
   my $mismatches   = $align->get('mismatches');
   my $repmatches   = $align->get('rep_matches');
   my $ns           = $align->get('num_ns');
   my $alignedBases = ($matches + $mismatches + $repmatches + $ns);
   my $alignPct     = ($alignedBases / $qSize) * 100.0;
   if ($alignPct < $minQueryPct){
##     print STDERR "$query_id vs $target_id: fails to meet minQueryPct ($minQueryPct) with $alignPct\n";
     return 0; 
   }

   # TO DO - only retrieve sequence if needed?

   ##want to only check consistency if query is a dna sequence in which case the $qIndex will be defined
   my ( $qualityId,$has3p,$is3p,$has5p,$is5p,$qn,$tn,$pctId,
         $maxQGap,$maxTGap,$numSpans, $minQs, $maxQe, $strand, $end3, $end5 );
   if(defined $qIndex){
     # Retrieve sequence and compute quality
     # - now using BioPerl seqs
     #my $querySeq = $qIndex->getSequence(CBIL::Util::TO->new({accno => $origQueryId, strip => 1}));
     my $querySeq = $qIndex->getBioSeq( accno => $origQueryId, strip => 1 );
     
     # Disp::Display($querySeq);
     
     #my @a = $align->checkQuality($querySeq->{'seq'}, $qualityParams, $gapTable, $dbh);
     my @a = $align->checkQuality($querySeq->seq(), $qualityParams, $gapTable, $dbh);
     
     # determine BLAT alignment quality id (as specified in BlatProteinAlignmentQuality table)
     ( $qualityId,$has3p,$is3p,$has5p,$is5p,$qn,$tn,$pctId,$alignedBases,
         $maxQGap,$maxTGap,$numSpans, $minQs, $maxQe, $ts, $te, $strand, $end3, $end5
       ) = @a;
   }else{ ##the queries are proteins and we'll make up values to pass in when needed.
     ( $qualityId,$has3p,$is3p,$has5p,$is5p,$qn,$tn,$pctId,$alignedBases,
         $maxQGap,$maxTGap,$numSpans, $minQs, $maxQe, $ts, $te, $strand, $end3, $end5
       ) = ( 1,1,1,1,1,$align->get('q_name'),$align->get('t_name'),$alignPct,$alignedBases,1,1,$align->get('num_blocks'),$qs,$qe,$ts,$te,$align->get('strand'),1,1 );

   }
   my $isConsist = ($qualityId == 1 ? 1 : 0);

   ##need to deal with the target sequence when reversecomplemented
   my $isRev = $strand =~ /-/ ? 1 : 0;
   my $blockSizes = "";
   my $tStarts = "";
   my $tlength = $align->get('t_size');
   my $tmpBS = $align->getRaw('block_sizes');
   chop $tmpBS;
   my @bs = split(",",$tmpBS);
   my $tmpTS = $align->getRaw('t_starts');
   chop $tmpTS;
   my @ts = split(",",$tmpTS);
   my $a = scalar(@ts) - 1;
   if($isRev){
     for($a;$a >= 0;$a--){
       my $fbs = 3 * $bs[$a];
       $blockSizes .= "$fbs,";
       $tStarts .= ($tlength - $ts[$a] - $fbs).",";
     }
   }else{
     for(my $a = 0;$a <scalar(@ts);$a++){
       my $fbs = 3 * $bs[$a];
       $blockSizes .= "$fbs,";
     }
     $tStarts = $align->getRaw('t_starts');
   }

   my @values = ($query_id,
                 $target_id,
                 $queryTableId,
                 $queryTaxonId,
                 $queryExtDbRelId,
                 $targetTableId,
                 $targetTaxonId,
                 $targetExtDbRelId,
                 $isConsist,
                 0,
                 $end3, $end5,
                 $has3p, $has5p,
                 $is3p, $is5p,
                 $pctId,
                 $maxQGap,
                 $maxTGap,
                 $numSpans,
                 $qs, $qe,
                 $ts, $te,
                 $isRev,
                 $alignedBases,
                 $align->get('rep_matches'),
                 $align->get('num_ns'),
                 $align->getScore(),
                 0,
                 $qualityId,
                 $blockSizes,
                 $align->getRaw('q_starts'),
                 $tStarts
                );
   $sth->execute(@values)
   or die "$sql failed with values: \n" . join(", ", @values)  . "\n";

   return 1;
}

# Return the na_sequence_id for of a TIGR TC.
#
sub getQueryNaSeqId {
   my ($self,$dbh, $qid, $queryTableName) = @_;
    
   #    return $qid if $queryTableId =~ /^56|339$/;
   #    return $qid if $queryTableId == 89 && $qid =~ /^\d+$/;
   return $qid if $queryTableName =~ /^(?:assembly|splicednasequence)$/;
   return $qid if $queryTableName eq 'externalnasequence' && $qid =~ /^\d+$/;

   my $sql;
   if ($queryTableName eq 'externalnasequence') {
      $sql = "select na_sequence_id from $TPREF.externalnasequence where source_id = '$qid'";
   } elsif ($queryTableName eq 'assemblysequence') {
      $sql = "select na_sequence_id from $TPREF.assemblysequence where assembly_sequence_id = $qid";
   } elsif ($queryTableName =~ /aasequence$/) {
      $sql = "select aa_sequence_id from $TPREF.aasequence where source_id = '$qid'";
   }

   my $sth = $dbh->prepareAndExecute($sql);
   my($sid) =  $sth->fetchrow_array();
   $sth->finish();       
   return $sid;
}

# Return the genome version for given external databaser release id
#
sub getGenomeVersion {
   my ($self,$dbh, $ext_db_rel_id) = @_;

   my $sql = "select version from SRES.ExternalDatabaseRelease " .
   "where external_database_release_id = ?";
   my $sth = $dbh->prepare($sql) or die "bad sql $sql: $!";
   $sth->execute($ext_db_rel_id) or die "could not run $sql: $!";
   my @vers;
   while (my ($v) = $sth->fetchrow_array) {
      push @vers, $v;
   }
   my $c = $#vers+1;
   die "expected 1 entry but got $c\n" unless $c == 1;

   my $v = $vers[0];

   $v;
}

sub undoTables {
  my ($self) = @_;

  return ("$BLATSCHEMA.BlatProteinAlignment"
	 );
}



1;
