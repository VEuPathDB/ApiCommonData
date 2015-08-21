package ApiCommonData::Load::BindingFactor2BioperlTree;


use strict;
use Bio::SeqFeature::Generic;
use Bio::Location::Simple;
use ApiCommonData::Load::BioperlTreeUtils qw{makeBioperlFeature};

#input: CDS with join location (if multiple exons)
#output: standard api tree: gene->transcript->exons
#                                           ->CDS

sub preprocess {
  my ($bioperlSeq, $plugin) = @_;


  foreach my $bioperlFeatureTree ($bioperlSeq->get_SeqFeatures()) {
  

 
      
      if($bioperlFeatureTree->score()){
	  $bioperlFeatureTree->add_tag_value('primary_score',$bioperlFeatureTree->score());
	  $bioperlFeatureTree->remove_tag('score');
      }

    }
}



1;
