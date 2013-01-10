package ApiCommonData::Load::SimpleGene2BioperTree;

# Remove existing gene features, promote CDS, tRNA, etc to gene

use strict;
use Bio::SeqFeature::Generic;
use Bio::Location::Simple;
use ApiCommonData::Load::BioperlTreeUtils qw{makeBioperlFeature};
use Data::Dumper;

#input:
#
# gene  [folded into CDS]
#
#output: standard api tree: gene->transcript->exons

# (0) remove all seq features, add back the non-genes
# (1) copy old gene qualifiers to cds/rna feature
# (2) retype CDS into Gene
# (3) remember its join locations
# (4) create transcript, give it a copy of the gene's location
# (5) add to gene
# (6) create exons from sublocations
# (7) add to transcript


sub preprocess 
{
	my ($bioperlSeq, $plugin) = @_;

	my @seqFeatures = $bioperlSeq->get_SeqFeatures;

	foreach my $bioperlFeatureTree (@seqFeatures) {
		my $type = $bioperlFeatureTree->primary_tag();
		
		if ($type eq 'gene') {
			$type = "coding";

			$bioperlFeatureTree->primary_tag("${type}_gene");

			my $gene = $bioperlFeatureTree;
			my $geneLoc = $gene->location();
		
			#$bioperlSeq->add_SeqFeature($gene) if ($gene);
			#every gene has been load twice, maybe problem is here.

			my $transcript = &makeBioperlFeature("transcript", $geneLoc, $bioperlSeq);
			$gene->add_SeqFeature($transcript);

			my $codonStart = 0;
			$codonStart = $bioperlFeatureTree->get_tag_values("codon_start") 
				if ( $bioperlFeatureTree->has_tag("codon_start") );
			
			my @exonLocs = $geneLoc->each_Location();
			my $CDSLength = 0;
			# my $CDSLoc = $geneLoc;

			my (@exons, @sortedExons);
			foreach my $exonLoc (@exonLocs) {
				my $exon = &makeBioperlFeature("exon", $exonLoc, $bioperlSeq);
				
				my ($codingStart, $codingEnd);
				#if ($type eq 'coding') {
                                if ($exon->location->strand == -1) {
					$codingStart = $exon->location->end;
					$codingEnd = $exon->location->start;
					#$codingStart -= $codonStart if ($codonStart > 0);
                                } else {
					$codingStart = $exon->location->start;
					$codingEnd = $exon->location->end;
					#$codingStart += $codonStart if ($codonStart > 0);
				}
				$exon->add_tag_value('CodingStart', $codingStart);
				$exon->add_tag_value('CodingEnd', $codingEnd);
				$exon->add_tag_value('type', 'coding');
				# } else {
				#	$exon->add_tag_value ('CodingStart', '');
				#	$exon->add_tag_value ('CodingEnd', '');
				#	$exon->add_tag_value ('type', 'non_coding');
				#}
			
				$CDSLength += (abs($codingStart - $codingEnd) + 1);
				push (@exons, $exon);
			}

			$transcript->add_tag_value('CDSLength', $CDSLength);

			my $naReminder = $CDSLength%3;
			my $exonCount = 0;
	
			foreach my $exon (sort {$a->location->start() <=> $b->location->start()} @exons) {
				$transcript->add_SeqFeature($exon);
				$exonCount++;
			}
		}
	}
}


1;
