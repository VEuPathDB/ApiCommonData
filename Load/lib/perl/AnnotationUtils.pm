package ApiCommonData::Load::AnnotationUtils;

## a useful collection of subroutine that be used by annotation analysis
## in order to use the subroutine in this module, include the following line at the "use" section in perl script
## use ApiCommonData::Load::AnnotationUtils;

use List::Util qw[min max];  ## include the min and max subroutine that take min or max of more than 2 items
## usage: max ($ends{$cGene}, $items[3], $items[4])
## usage: min ($ends{$cGene}, $items[3], $items[4])
use Bio::SeqIO;
use Bio::Tools::GFF;
use Bio::Seq::RichSeq;
use GUS::Supported::SequenceIterator;
use ApiCommonData::Load::BioperlTreeUtils qw{makeBioperlFeature};
use CBIL::Bio::SequenceUtils;


sub getSeqIO {
  my ($inputFile, $format, $gff2GroupTag) = @_;
  my $bioperlSeqIO;

  if ($format =~ m/^gff([2|3])$/i) {
    print STDERR "pre-processing GFF file ...\n";
    $bioperlSeqIO = convertGFFStreamToSeqIO($inputFile,$1,$gff2GroupTag);
    print STDERR "done pre-processing gff file\n";
  } else {
    $bioperlSeqIO = Bio::SeqIO->new (-format => $format,
				     -file => $inputFile);
  }
  return $bioperlSeqIO;
}

## usage: &printGff3Column (\@items);
sub printGff3Column {
  my $array = shift;
  foreach my $i (0..$#{$array}) {
    ($i == 8) ? print "$array->[$i]\n" : print "$array->[$i]\t";
  }
  return 0;
}

## usage: &printTabDelimitedLine (\@items);
## print a tab delimited line, a new line char after the last item, and a tab char after the rest items
sub printTabDelimitedLine {
  my $array = shift;
  foreach my $i (0..$#{$array}) {
    ($i == 8) ? print "$array->[$i]\n" : print "$array->[$i]\t";
  }
  return 0;
}

## read bioperl features from a gff3 file
sub readFeaturesFromGff {
  my ($inFile) = @_;
  my @bioFeats;
  my $gffio = Bio::Tools::GFF->new(-file => $inFile, -gff_version => 3);
  while (my $feature = $gffio->next_feature()) {
    $feature->gff_format(Bio::Tools::GFF->new(-gff_version => 3));
    my $type = $feature->primary_tag();
    my ($id) = $feature->get_tag_values("ID") if ($feature->has_tag("ID"));
    push @bioFeats, $feature;
  }
  $gffio->close();

  return \@bioFeats;
}

sub nestGeneHierarchy{ ## gene -> transcript -> exon
  my ($feature) = @_;

  ## use ID/Parent hierarchy to re-nest GFF3 features
  my %top;          # associative list of top-level features
  my %children;     # mapping of parents to children
  my @keep;         # list of features to replace flat feature list

  foreach my $feat (@{$feature}) {
    my $seqId = $feat->seq_id;
    my $id;
    if ($feat->has_tag("ID")) {
      ($id) = $feat->get_tag_values("ID");
    } else {
      my $start = $feat->location->start();
      my $end = $feat->location->end();
      warn "For '$seqId', no ID found at position: $start ... $end\n";
    }

    if ($feat->has_tag("Parent")) {
      foreach my $parent($feat->get_tag_values("Parent")) {
        push @{$children{$parent}}, [$id, $feat];
      }
    } elsif ($feat->has_tag("Derives_from")) {
      foreach my $parent($feature->get_tag_values("Derives_from")) {
        push @{$children{$parent}}, [$id, $feat];
      }
    } else {
      push @keep, $feat;
      $top{$id} = $feat if ($id);   # only features with ID can have children
    }
  }  # end of foreach my $feat 

  # build a stack of children to be associated with their parent feature
  foreach my $k (sort keys %top) {
    my @children;
    if ($children{$k}) {
      foreach my $col (@{$children{$k}}) {
        push @children, [@$col, $top{$k}];
      }
    }
    delete($children{$k});

    # now iterate over the stack until empty
    foreach my $child (@children) {
      my ($child_id, $child, $parent) = @$child;

      # make the association
      if ($parent->location->start() > $child->location->start() ) {
        warn "Child feature $child_id does not lie (start) within parent boundaries\n";
        $parent->location->start($child->location->start());
      }
      if ($parent->location->end() < $child->location->end() ) {
        warn "Child feature $child_id does not lie (end) within parent boundaries\n";
        $parent->location->end($child->location->end());
      }
      $parent->add_SeqFeature($child);

      # add to the stack any nested children of this child
      if ($children{$child_id}) {
        foreach my $col (@{$children{$child_id}}) {
          push @children, [@$col, $child];
        }
      }
      delete ($children{$child_id});
    }
  }

  # the entire contents of %children should now have been processed
  if ( keys %children) {
    warn "Unassociated children features (missing parents):\n";
    warn join ("\n    ", keys %children), "\n";
  }

  # replace original feature list with new nested versions
  @{$feature} = @keep;

  return $feature;
}

sub flatGeneHierarchySortBySeqId {
  my ($feat) = @_;

  # sort by seq_id, then bioFeat->location
  my %sortedFeats;
  foreach my $eachFeat (@{$feat}) {
    my $seqId = $eachFeat->seq_id();
    push @{$sortedFeats{$seqId}}, $eachFeat;
  }

  my $flatFeature;
  foreach my $k (sort keys %sortedFeats) {
    foreach my $gene ( sort {$a->location->start <=> $b->location->start
                               || $a->location->end <=> $b->location->end} @{$sortedFeats{$k}}) {
      push @{$flatFeature}, $gene;

      # gene->mRNA1->exon(/CDS)->mRNA2->exon(CDS)->mRNA3 ...
      foreach my $transcript ($gene->get_SeqFeatures()) {
        push @{$flatFeature}, $transcript;
        foreach my $exon ($transcript->get_SeqFeatures()) {
          push @{$flatFeature}, $exon;
        }
      }

      # gene->mRNA1->mRNA2->mRNA3 ... ->exon ... ->CDS ... ## not working because it also delete some CDS and utr features
#      my (%subFeats, $exonK);
#      foreach my $transcript ($gene->get_SeqFeatures()) {
#        push @{$flatFeature}, $transcript;
#        foreach my $exon ($transcript->get_SeqFeatures()) {
#	  $exonK = $seqId."_".$exon->primary_tag()."_".$exon->location->start."-". $exon->location->end;
#          push @{$flatFeature}, $exon; #if (!$subFeats{$exonK});
#	  $subFeats{$exonK} = $exon;
#	}
#      }
    }
  }

  return $flatFeature;
}


sub writeFeaturesToGffBySeqId {
  my ($bioFeat, $out) = @_;

  my $gffout= Bio::Tools::GFF->new(-file => ">$out", -gff_version => 3);

  # sort by seq_id
  my %sortedBioFeats;
  foreach my $feat (@{$bioFeat}) {
    my $seqId = $feat->seq_id();
    push @{$sortedBioFeats{$seqId}}, $feat;
  }

  foreach my $k (sort keys %sortedBioFeats) {
    foreach my $sortedFeat (@{$sortedBioFeats{$k}}) {
      $gffout->write_feature($sortedFeat);
    }
  }

  $gffout->close();

  return 0;
}

sub verifyFeatureLocation {
  my ($bioFeatures) = @_;

  my (%bioFeatureHash);
  foreach my $bioFeature (@{$bioFeatures}) {
    my $seqId = $bioFeature->seq_id();
    push @{$bioFeatureHash{$seqId}}, $bioFeature;
  }

  foreach my $k (sort keys %bioFeatureHash) {
    foreach my $gene (@{$bioFeatureHash{$k}}) {

      my ($gene_id) = $gene->get_tag_values("ID") if ($gene->has_tag("ID"));
      my $gstart = $gene->location->start;
      my $gend = $gene->location->end;
#      print STDERR "gene $gene_id starts at $gstart, and ends at $gend\n"
#	if ($gene_id eq "AMAG_10791" || $gene_id eq "AMAG_16866");

      foreach my $transcript ($gene->get_SeqFeatures) {
	my ($mRNA_id) = $transcript->get_tag_values("ID") if ($transcript->has_tag("ID"));
	my $tstart = $transcript->location->start;
	my $tend = $transcript->location->end;
#	print STDERR "transcript $mRNA_id starts at $tstart, and ends at $tend\n"
#	  if ($mRNA_id eq "AMAG_10791-t26_1" || $mRNA_id eq "AMAG_16866-t26_1");

	&checkFeatureLocation ($gene, $transcript);

	foreach my $exon ($transcript->get_SeqFeatures) {
	  my ($exon_id) = $exon->get_tag_values("ID") if ($exon->has_tag("ID"));
	  my $estart = $exon->location->start;
	  my $eend = $exon->location->end;
#	  print STDERR "exon $exon_id starts at $estart, and ends at $eend\n"
#	    if ($exon_id eq "exon_AMAG_10791-E1" || $exon_id eq "exon_AMAG_16866-E1");

	  &checkFeatureLocation ($transcript, $exon);
	}
      }
    }
  }
}

sub checkFeatureLocation {
  my ($parent, $child) = @_;

  my ($parent_id) = $parent->get_tag_values("ID") if ($parent->has_tag("ID"));
  my ($child_id) = $child->get_tag_values("ID") if ($child->has_tag("ID"));
  if ($parent->location->start() > $child->location->start() ) {
    warn "Child feature '$child_id' does not lie (start) within parent '$parent_id' boundaries\n";
    $parent->location->start($child->location->start());
  }
  if ($parent->location->end() < $child->location->end() ) {
    warn "Child feature '$child_id' does not lie (end) within parent '$parent_id' boundaries\n";
    $parent->location->end($child->location->end());
  }
}

sub checkGff3Format {
  my ($bioFeature) = @_;

  my (%geneIds, %exonFeats);
  foreach my $bioFeat (@{$bioFeature}) {
    my $seqId = $bioFeat->seq_id;
    my $type = $bioFeat->primary_tag;
    my $start = $bioFeat->location->start;
    my $end = $bioFeat->location->end;
    my $strand = $bioFeat->strand;
    my $frame = $bioFeat->frame;
    my ($id) = $bioFeat->get_tag_values("ID") if ($bioFeat->has_tag("ID"));

#    print STDERR "For $type: $id, \$strand = $strand\n";

    ## 1) check if gene ID is unique and not null
    if ($id eq "") {
      warn "At $seqId, $start ... $end, gene ID can not be null.\n";
    }

    if ($type eq "gene" || $type eq "pseudogene") {
      #($geneIds{$id}) ? warn "At $seqId, $start ... $end, gene ID has been duplicated.\n" : $geneIds{$id} = $id;
      if ($geneIds{$id}) {
	warn "At $seqId, $start ... $end, gene ID: '$id' has been duplicated.\n";
      } else {
	$geneIds{$id} = $id;
      }
    }

    # 2) check the lenght of sequence ID is not hit the max 50 characters
    my $seqIdLength = length ("$seqId");
    warn "For '$seqId', the length of sequence ID can not hit the max 50 characters.\n" if ($seqIdLength > 50);

    # 3) check if frame should be 0, 1, 2 for CDS, should be . for all others
    if ($type eq "CDS") {
      unless ($frame eq "0" || $frame eq "1" || $frame eq "2") {
	warn "For the CDS: $id at $seqId, the frame at the 8th column should be 0|1|2\n";
      }
    } else {
      if ($frame ne "\.") {
	warn "For $type: $id at $seqId, the frame at the 8th column should be an '.'\n";
      }
    }

    # 4) check if the strand is + or -
    unless ($strand eq "1"  || $strand eq "-1") {
      warn "For $type $id, the 7th column is strand info. It can not be $strand. It should be +|-\n";
    }

    # 5) check if overlapped exons for each transcript
    # 5) check if there is any duplicated exons for each transcript
    if ($type =~ /exon$/) {
      my @parentIds = $bioFeat->get_tag_values("Parent") if ($bioFeat->has_tag("Parent"));
      foreach my $parentId (@parentIds) {
	push @{$exonFeats{$parentId}}, $bioFeat;
      }
    }


  }

  # 5) check if overlapped exons or duplicated exons for each transcript
  foreach my $k (sort keys %exonFeats) {
    my ($preStart, $preEnd);
    foreach my $exon ( sort {$a->location->start <=> $b->location->start
                               || $a->location->end <=> $b->location->end} @{$exonFeats{$k}}) {
      if ($preEnd > $exon->location->start && defined ($preStart && $preEnd)) {
	my ($sid) = $exon->get_tag_values("ID") if ($exon->has_tag("ID"));
	my $sStart = $exon->location->start;
	my $sEnd = $exon->location->end;
	warn "overlapped exons found at $sid: $sStart ... $sEnd for $k\n";
      } else {
	$preStart = $exon->location->start;
	$preEnd = $exon->location->end;
      }
    }
  }
}


sub checkGff3FormatNestedFeature {
  my ($bioFeature) = @_;

  my (%geneIds, %exonFeats, %dupGenes);
  foreach my $bioFeat (@{$bioFeature}) {
    my $seqId = $bioFeat->seq_id;
    my $type = $bioFeat->primary_tag;
    my $start = $bioFeat->location->start;
    my $end = $bioFeat->location->end;
    my $strand = $bioFeat->strand;
    my $frame = $bioFeat->frame;
    my ($id) = $bioFeat->get_tag_values("ID") if ($bioFeat->has_tag("ID"));

    # 6) check if all subFeatures of a gene are located at the same strand
    foreach my $transcript ($bioFeat->get_SeqFeatures) {
      my ($tId) = $transcript->get_tag_values("ID") if ($transcript->has_tag("ID"));
      my $tStrand = $transcript->strand;
      my $tLength = abs($transcript->location->end - $transcript->location->start) +1;
      my ($eLength, $cdsLen);

      if ($transcript->strand ne $strand) {
	warn "Feature gene $id ($strand) and transcript $tId ($tStrand) are not located at the same strand\n";
	next;
      }
      foreach my $exon ($transcript->get_SeqFeatures) {
	my ($eId) = $exon->get_tag_values("ID") if ($exon->has_tag("ID"));

	if ($exon->strand ne $transcript->strand) {
	  warn "Feature exon $eId and transcript $tId are not loacated at the same strand\n";
	}

	if ($exon->primary_tag eq "exon") {
	  $eLength += abs($exon->location->end - $exon->location->start) + 1;
	}
	if ($exon->primary_tag eq "CDS") {
	  $cdsLen += abs($exon->location->end - $exon->location->start) + 1;
	}
      }

      # 8) check the length of transcript is not shorter than the sum of the exons's length
      if ($tLength < $eLength) {
	warn "Feature transcript: $tId, the length of transcript is shorter than the sum of the exons\n";
	warn "    double check the number of exons and locations of exons\n";
      }

      # 9) check if the length of aa sequence < 10 aa
      if ($cdsLen > 0 && $cdsLen < 30) {
	warn "Feature transcript: $tId, the length of translation < 10 aa\n";
      }

    } # end of foreach my $transcript

    # 7) check if duplicated genes happen in the same sequence at the same position
    # use geneStart, geneEnd, and strand as a key, the value is the strand
    my $geneKey = $seq_id."-".$start."-".$end;
    if ($dupGenes{$geneKey}) {
      ($dupGenes{$geneKey} eq $strand) ? warn "Duplicated gene found at $seqId: $start ... $end at the same strand\n" 
	: warn "Duplicated gene found at $seqId: $start ... $end, but at a different strand\n";
    } else {
      $dupGenes{$geneKey} = $strand;
    }

  } # end of foreach my $bioFeat
}

sub checkGff3GeneModel {
  my ($bioFeature, $fastaFile, $codon_table, $specialCodonTable) = @_;

  my (%seqs, $key);
  open (FA, "$fastaFile") || die "can not open fastaFile to read\n";
  while (<FA>) {
    chomp;
    if ($_ =~ /^>(\S+)/) {
      $key = $1;
    } else {
      $seqs{$key} .= $_;
    }
  }
  close FA;

  my %specialCodonTables;
  if ($specialCodonTable) {
    my @tables = split (/\,/, $specialCodonTable);
    foreach my $table (@tables) {
      my ($seq, $table) = split (/\|/, $table);
      $specialCodonTables{$seq} = $table;
    }
  }

  ## 10) check if gene location is located outside the naSequence length
  my $flatBioFeature = flatGeneHierarchySortBySeqId($bioFeature);
  foreach my $feat (@{$flatBioFeature}) {
    my $seqId = $feat->seq_id();
    if ($feat->location->start > length ($seqs{$seqId}) || $feat->location->end > length ($seqs{$seqId}) ) {
      my ($fid) = $feat->get_tag_values("ID") if ($feat->has_tag("ID"));
      my $fstart = $feat->location->start;
      my $fend = $feat->location->end;
      my $seqLen = length ($seqs{$seqId});
      warn "Feature $fid $fstart ... $fend is located outside sequence boundary $seqId: $seqLen\n";
    }
  }

  ## 11) check if internal stop codon
  my (%CDSs);
  foreach my $subFeat (@{$bioFeature}) {
    foreach my $transcript ($subFeat->get_SeqFeatures) {
      my ($tId) = $transcript->get_tag_values("ID") if ($transcript->has_tag("ID"));
      foreach my $exon (sort {$a->location->start <=> $b->location->start
				|| $a->location->end <=> $b->location->end} $transcript->get_SeqFeatures ) {

	if ($exon->primary_tag() eq "CDS") {
	  push @{$CDSs{$tId}}, $exon;
	}
      }
    }
  }

  foreach my $tId (sort keys %CDSs) {
    my ($cdsSeq, $tStrand, $seqId);
    my $c = 0;
    foreach my $exon (sort {$a->location->start <=> $b->location->start
                                || $a->location->end <=> $b->location->end} @{$CDSs{$tId}}) {

      $seqId = $exon->seq_id;
      my $estart = $exon->location->start;
      my $eend = $exon->location->end;
      my $eframe = $exon->frame;
      $tStrand = $exon->strand;

      ## only the 1st CDS for plus strand and the last CDS for minus strand need to deal with frame
      if ($exon->strand == 1 && $c == 0) {
	$cdsSeq .= substr ($seqs{$seqId}, $estart+$eframe-1, ($eend-$estart-$eframe+1) );
      } elsif ($exon->strand == -1 && $c == $#{$CDSs{$tId}} ) {
	$cdsSeq .= substr ($seqs{$seqId}, $estart-1, ($eend-$eframe-$estart+1) );
      } else {
	$cdsSeq .= substr ($seqs{$seqId}, $estart-1, ($eend-$estart+1) );
      }
      $c++;
    }

    ## get translation
    if ($tStrand == -1) {
      $cdsSeq = revcomp ($cdsSeq);
    }

    my $proteinSeq;
    if ($specialCodonTables{$seqId}) {
      $proteinSeq = CBIL::Bio::SequenceUtils::translateSequence($cdsSeq,$specialCodonTables{$seqId});
    } else {
      $proteinSeq = CBIL::Bio::SequenceUtils::translateSequence($cdsSeq,$codon_table);
    }

    print STDERR ">$tId\n$proteinSeq\n";
    $proteinSeq =~ s/\*+$//;

    ## check
    if ($proteinSeq =~ /\*/) {
      warn "WARNING: transcript $tId contains internal stop codons\n";
    }
  }
  # end of checking if internal stop codon.


  # check if there is internal UTR, the UTRs is inside the CDS

}


sub revcomp {
  my $seq = shift;
  my $rev = reverse($seq);
  $rev =~ tr/ACGT/TGCA/;
  return $rev;
}

## usage: $aspect = getAspectForGo ($value);
sub getAspectForGo {
        my ($line) = @_;
        my $aspect;

        if ($line eq /[C|F|P]/) {
                $aspect = $line; 
        } elsif (lc($line) =~ /component/) {
                $aspect = 'C';
        } elsif (lc($line) =~ /function/) {
                $aspect = 'F';
        } elsif (lc($line) =~ /process/) {
                $aspect = 'P';
        } else {
                $aspect = '';
        }
        return $aspect;
}


## usage: &generateGoArray($lineWithGoInfo);
## pass in a line with GO info, print an array contains all GO items that can print a .gaf file
## my @goArray = generateGoArray($line);
## &printTabDelimitedLine (\@goArray);
sub generateGoArray {
  my ($line) = @_;
  my ($aspect, $goId, $dbxref, $evidenceCode, $withOrFrom, $product, $synonym, $sourceIdType);

  $evidenceCode = "IEA";  ## default value

  if ($line =~ /^GO_component/ || $line =~ /^GO_function/ || $line =~ /^GO_process/) {
    ($aspect) = split (/\:/,$line);
    if ($line =~ /(GO_\w+?): (GO:\d+?) - (.+?);ev_code=(\w+?)$/) {
      $aspect = &getAspectForGo ($1);
      $goId = $2;
      $product = $3;
      $evidenceCode = $4;
    } elsif ($line =~ /GO:(\d+) - (.+)$/) {
      $goId = "GO:".$1;
      $product = $2;
      $aspect = &getAspectForGo ($line);
    }
  } else {
    my @facts = split (/\;/, $line);
    foreach my $fact (@facts) {
      my ($f, $v) = split (/\=/, $fact);
      if ($f eq "aspect") {
        $v =~ s/GO:\s+//;
        $aspect = $v;
      } elsif ($f eq "GOid" ) {
        $goId = $v;
        $goId =~ s/GO://;
      } elsif ($f eq "term" ) {
        $product = $v;
      } elsif ($f eq "evidence") {
        $evidenceCode = $v;
      }
    }
  }
  my @items;
  $items[0] = $db;
  $items[1] = $sourceId;
  $items[2] = $sourceId;                 ## DB Object Symbol, eg geneName
  $items[3] = "";                        ## Qualifier, 0 or greater
  $items[4] = $goId;
  $items[5] = $dbxref;                   ## DB:Reference, eg PMID:2676709;
  $items[6] = $evidenceCode;
  $items[7] = $withOrFrom;               ## With or From
  $items[8] = $aspect;
  $items[9] = $product;                  ## db object name, 0 or 1
  $items[10] = $synonym;                 ## db object synonym, 0 or greater
  $items[11] = "transcript";             ## db object type
  $items[12] = "taxon:".$taxonId;        ## eg taxon:9606
  $items[13] = $date;                    ## eg 20150817
  $items[14] = $db;                      ## Assigned By

#  my $tabDelimitLine;
#  foreach my $i (0..14) {
#    $tabDelimitLine .= ($i == 14) ? "$items[$i]\n" : "$items[$i]\t";
#  }

#  return $tabDelimitLine;
  return \@items;
}




sub getGoEvidenceCode {
  my ($string) = @_;

  if ($string =~ /INFERRED FROM ELECTRONIC ANNOTATION/i) {
    return "IEA";
  } elsif ($string =~ /INFERRED FROM SEQUENCE ORTHOLOGY/i) {
    return "ISO";
  } elsif ($string =~ /NOT RECORDED/i) {
    return "NR";
  } elsif ($string =~ /INFERRED FROM DIRECT ASSAY/i) {
    return "IDA";
  } elsif ($string =~ /No biological Data available/i) {
    return "ND";
  } elsif ($string =~ /INFERRED FROM SEQUENCE OR STRUCTURAL SIMILARITY/i) {
    return "ISS";
  } elsif ($string =~ /Inferred from Sequence Alignment/i) {
    return "ISA";
  } elsif ($string =~ /Inferred from Sequence Model/i) {
    return "ISM";
  } elsif ($string =~ /Inferred from Genomic Context/i) {
    return "IGC";
  } elsif ($string =~ /Inferred from Biological aspect of Ancestor/i) {
    return "IBA";
  } elsif ($string =~ /Inferred from Biological aspect of Descendant/i) {
    return "IBD";
  } elsif ($string =~ /Inferred from Key Residues/i) {
    return "IKR";
  } elsif ($string =~ /Inferred from Rapid Divergence /i) {
    return "IRD";
  } elsif ($string =~ /inferred from Reviewed Computational Analysis/i) {
    return "RCA";
  } elsif ($string =~ /Inferred from Experiment/i) {
    return "EXP";
  } elsif ($string =~ /Inferred from Physical Interaction/i) {
    return "IPI";
  } elsif ($string =~ /Inferred from Mutant Phenotype/i) {
    return "IMP";
  } elsif ($string =~ /Inferred from Genetic Interaction/i) {
    return "IGI";
  } elsif ($string =~ /Inferred from Expression Pattern/i) {
    return "IEP";
  } elsif ($string =~ /Traceable Author Statement/i) {
    return "TAS";
  } elsif ($string =~ /Non-traceable Author Statement/i) {
    return "NAS";
  } elsif ($string =~ /Inferred by Curator/i) {
    return "IC";
  } else {
    return $string;
  }
}

sub convertGFFStreamToSeqIO {

  my ($inputFile, $gffVersion, $gff2GroupTag) = @_;

  # convert a GFF "features-referring-to-sequence" stream into a
  # "sequences-with-features" stream; also aggregate grouped features.

  die("For now, gff formats only support a single file") if (-d $inputFile);

  my @aggregators = &makeAggregators($inputFile,$gffVersion,$gff2GroupTag);

  my $gffIO = Bio::Tools::GFF->new(-file => $inputFile,
                                   -gff_format => $gffVersion
                                  );

  my %seqs; my @seqs;
  while (my $feature = $gffIO->next_feature()) {
    push @{$seqs{$feature->seq_id}}, $feature;
  }

  while (my ($seq_id, $features) = each %seqs) {
    my $seq = Bio::Seq::RichSeq->new( -alphabet => 'dna',
                             -molecule => 'dna',
                             -molecule => 'dna',
                             -display_id => $seq_id,
                             -accession_number => $seq_id,
                           );

    if ($gffVersion < 3) {
      # GFF2 - use group aggregators to re-nest subfeatures
      for my $aggregator (@aggregators) {
        $aggregator->aggregate($features);
      }
    } else {
      # GFF3 - use explicit ID/Parent hierarchy to re-nest
      # subfeatures

      my %top;      # associative list of top-level features: $id => $feature
      my %children; # mapping of parents to children:
                    # $parent_id => [ [$child_id, $child],
                    #                 [$child_id, $child],
                    #               ]
      my @keep;     # list of features to replace flat feature list.

      # first, fill the datastructures we'll use to rebuild
      for my $feature (@$features) {
        my $id = 0;
        ($id) = $feature->each_tag_value("ID")
          if $feature->has_tag("ID");

        if ($feature->has_tag("Parent")) {
          for my $parent ($feature->each_tag_value("Parent")) {
            push @{$children{$parent}}, [$id, $feature];
          }
        }  elsif ($feature->has_tag("Derives_from")) {
          for my $parent ($feature->each_tag_value("Derives_from")) {
            push @{$children{$parent}}, [$id, $feature];
          }
        } else {
          push @keep, $feature;
          $top{$id} = $feature if $id; # only features with IDs can
                                       # have children
        }
      }

      while (my ($id, $feature) = each %top) {
        # build a stack of children to be associated with their
        # parent feature:
        # [$child_id, $child_feature, $parent_feature]
        my @children;
        if($children{$id}){
          foreach my $col (@{$children{$id}}){
            push @children ,[@$col,$feature];
          }
        }
        delete($children{$id});

        # now iterate over the stack until empty:
        foreach my $child (@children) {
          my ($child_id, $child, $parent) = @$child;

          ## check if the parent or child coordinates is negative 
          if ($parent->location->start < 0 || $parent->location->end < 0) {
            my ($cId) = $parent->get_tag_values('ID') if ($parent->has_tag('ID'));
            die "Unreason coordinates found at $cId: " . $parent->location->start . " : " . $parent->location->end . "\n";
          }
          if ($child->location->start < 0 || $child->location->end < 0) {
            my ($cId) = $child->get_tag_values('ID') if ($child->has_tag('ID'));
            die "Unreason coordinates found at $cId: " . $child->location->start . " : " . $child->location->end . "\n";
          }

          # make the association:
        my ($pId) = $parent->get_tag_values('ID') if ($parent->has_tag('ID'));
        my ($cId) = $child->get_tag_values('ID') if ($child->has_tag('ID'));
          if($parent->location->start() > $child->location->start()){
              warn "Child feature $child_id $cId does not lie within parent $pId boundaries.\n";

              $parent->location->start($child->location->start());
	    }

          if($parent->location->end() < $child->location->end()){
              warn "Child feature $child_id $cId does not lie within parent $pId boundaries.\n";

              $parent->location->end($child->location->end());
	    }

          $parent->add_SeqFeature($child);

          # add to the stack any nested children of this child
          if($children{$child_id}){
            foreach my $col (@{$children{$child_id}}){
              push @children ,[@$col,$child];
            }
          }
          delete($children{$child_id});
        }
      }
      # the entire contents of %children should now have been
      # processed:
      if (keys %children) {
        warn "Unassociated children features (missing parents):\n  ";
        warn join("  \n", keys %children), "\n";
      }

      # replace original feature list with new nested versions:
      @$features = @keep;
    }

    $seq->add_SeqFeature($_) for @$features;
    push @seqs, $seq;
  }

  return GUS::Supported::SequenceIterator->new(\@seqs);
}

sub makeAggregators {
  my ($inputFile, $gffVersion,$gff2GroupTag) = @_;

  return undef if ($gffVersion != 2);

  die("Must supply --gff2GroupTag if using GFF2 format") unless $gff2GroupTag;

  # a list of "standard" feature aggregator types for GFF2 support;
  # only "processed_transcript" for now, but leaving room for others
  # if necessary.
  my @aggregators = qw(Bio::DB::GFF::Aggregator::processed_transcript Bio::DB::GFF::Aggregator::transcript);

  # build Feature::Aggregator objects for each aggregator type:
  @aggregators =
    map {
      Feature::Aggregator->new($_, $gff2GroupTag);
    } @aggregators;
  return @aggregators;
}

1;
