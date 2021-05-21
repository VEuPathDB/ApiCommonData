#!/usr/bin/perl

use strict;

use lib $ENV{GUS_HOME} . "/lib/perl";

use ApiCommonData::Load::AlignmentFileReader;

use Getopt::Long;

use Data::Dumper;

my ($help, $blatFile, $outFile);

&GetOptions('h|help' => \$help,
            'blat_file=s' => \$blatFile,
            'output_file=s' => \$outFile
    );


my $qualityParams = {
  'maxEndMismatch' => 10,
  'minPctId' => 95,
  'maxQueryGap' => 5,
  'okInternalGap' => 15,
  'okEndGap' => 50,
  'endGapFactor' => 10,
  'minGapPct' => 90,
  'minQueryPct' => 10,
  'maxFeatureSize' => 5000,
};


my $reader = ApiCommonData::Load::AlignmentFileReader->new($blatFile, undef, "\t");

my $fh;
open($fh, ">$outFile") or die "Cannot open file $outFile for writing: $!";

my $nAligns = 0;

my $alreadyLoaded = {};

while($reader->hasNext()) {
  my $alignments = $reader->readNextGroupOfLines();
  
  my @sortedAlignments = sort { 
    $a->get('t_start') <=> $b->get('t_start') 
        || $a->get('t_end') <=> $b->get('t_end') 
        || $b->getScore() <=> $a->getScore() 
        || $b->getAlignedBases() <=> $a->getAlignedBases()
  } @$alignments;


  my ($features, $positions) = &compressAlignments(\@sortedAlignments);

  &flagAlignmentsForKeep($features, $positions);        

   foreach my $align (@$alignments) {
     next unless($align->{_keep}); #flagAlignmentsForKeep sets this

     ++$nAligns;

     my $nl = &printAlignmentAsGff($alreadyLoaded, $qualityParams, $align, $fh);
   }

}

close $fh;
print STDERR "Read $nAligns BLAT alignments from $blatFile.\n";

sub compressAlignments {
  my ($sortedAlignments) = @_;

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

sub flagAlignmentsForKeep {
  my ($featuresArrayRef, $positions) = @_;

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

sub printAlignmentAsGff {
   my ($alreadyLoaded, $qualityParams, $align, $fh) = @_;

   my $query_id  = $align->get('q_name');
   my $target_id = $align->get('t_name');

   my ($gi) = $query_id =~ /^gi\|(\d+)\|/;

   return unless $gi;

   # Check to see whether this alignment has already been loaded
   #
   my $qs = $align->get('q_start'); my $qe = $align->get('q_end');
   my $ts = $align->get('t_start'); my $te = $align->get('t_end');

   my $gffId    = join("_", ($gi, $target_id, $qs, $qe, $ts, $te));

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
   if ($alignPct < $qualityParams->{minQueryPct}){
     print STDERR "$query_id vs $target_id: fails to meet minQueryPct with $alignPct\n";
     return 0; 
   }


   my ( $qualityId,$has3p,$is3p,$has5p,$is5p,$qn,$tn,$pctId,$alignedBases,
     $maxQGap,$maxTGap,$numSpans, $minQs, $maxQe, $ts, $te, $strand, $end3, $end5
   ) = ( 1,1,1,1,1,$align->get('q_name'),$align->get('t_name'),$alignPct,$alignedBases,1,1,$align->get('num_blocks'),$qs,$qe,$ts,$te,$align->get('strand'),1,1 );

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

   my @values = ($query_id,                       #       QUERY_AA_SEQUENCE_ID
                 $target_id,                      #       TARGET_NA_SEQUENCE_ID
#                 $isConsist,                      #       IS_CONSISTENT
#                 $end3,                           #       UNALIGNED_3P_BASES
#                 $end5,                           #       UNALIGNED_5P_BASES
#                 $has3p,                          #       HAS_3P_POLYA
#                 $has5p,                          #       HAS_5P_POLYA
#                 $is3p,                           #       IS_3P_COMPLETE
#                 $is5p,                           #       IS_5P_COMPLETE
                 $pctId,                          #       PERCENT_IDENTITY
#                 $maxQGap,                        #       MAX_QUERY_GAP
#                 $maxTGap,                        #       MAX_TARGET_GAP
#                 $numSpans,                       #       NUMBER_OF_SPANS
                 $qs,                             #       QUERY_START
                 $qe,                             #       QUERY_END
                 $ts,                             #       TARGET_START
                 $te,                             #       TARGET_END
                 $isRev,                          #       IS_REVERSED
#                 $alignedBases,                   #       QUERY_BASES_ALIGNED
#                 $align->get('rep_matches'),      #       REPEAT_BASES_ALIGNED
#                 $align->get('num_ns'),           #       NUM_NS
                 $align->getScore(),              #       SCORE
#                 0,                               #       IS_BEST_ALIGNMENT
#                 $qualityId,                      #       BLAT_ALIGNMENT_QUALITY_ID
                 $blockSizes,                     #       BLOCKSIZES
#                 $align->getRaw('q_starts'),      #       QSTARTS
                 $tStarts                         #       TSTARTS
                );

   my $strand = $isRev == 1 ? "-" : "+";


   if($te - $ts > $qualityParams->{maxFeatureSize}) {
     return 0;
   }


   $ts = $ts + 1; #there is a one off error in the ts;
   print $fh "$target_id\tBLAT\tmatch\t$ts\t$te\t" . $align->getScore() . "\t$strand\t.\tID=$gffId;PercentIdentity=$pctId;GI=$gi\n";

   my @tstarts = map { s/\s+//g; $_+1 } split /,/, $tStarts;
   my @blocksizes = map { s/\s+//g; $_ } split /,/, $blockSizes;
   my $counter = 0;
   foreach my $start (@tstarts) {
     my $end = $start + $blocksizes[$counter] - 1;
     
     my $subId = $gffId . "_$counter";

     print $fh "$target_id\tBLAT\tmatch_part\t$start\t$end\t.\t$strand\t.\tID=$subId;Parent=$gffId\n";

     $counter = $counter + 1;
   }


   return 1;
}


1;
