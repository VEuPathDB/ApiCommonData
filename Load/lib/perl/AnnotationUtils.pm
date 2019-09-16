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
