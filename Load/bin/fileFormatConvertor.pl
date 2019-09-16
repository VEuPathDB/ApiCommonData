#!/usr/bin/perl

use strict;
use lib "$ENV{GUS_HOME}/lib/perl";
use Bio::SeqIO;
use Bio::SeqFeature::Tools::Unflattener;
use Bio::Tools::GFF;
use Bio::Seq::RichSeq;
use GUS::Supported::SequenceIterator;
use Bio::DB::GFF::Aggregator;
use Getopt::Long;
use FileHandle;

use Data::Dumper;

my ($inputFormat,$inputFileOrDir, $outputFile, $outputFormat, $unflatten, $gff2GroupTag, $help);

&GetOptions('help|h' => \$help,
            'unflatten' => \$unflatten,
            'gff2GroupTag=s' => \$gff2GroupTag,
	    'inputFormat=s' => \$inputFormat,
            'inputFileOrDir=s' => \$inputFileOrDir,
	    'outputFile=s' => \$outputFile,
	    'outputFormat=s' => \$outputFormat,
           );

&usage() if($help);
&usage("Missing a Required Argument") unless(defined $inputFormat && $inputFileOrDir);
&usage("gff2 files require gff2GroupTag argument") if($inputFormat eq 'gff2' && !($gff2GroupTag));

die "File or directory '$inputFileOrDir' does not exist\n" unless -e $inputFileOrDir;

my @files;
if (-d $inputFileOrDir) {
  opendir(DIR, $inputFileOrDir) || die "Can't open directory '$inputFileOrDir'";
  my @noDotFiles = grep { $_ ne '.' && $_ ne '..' } readdir(DIR);
  @files = map { "$inputFileOrDir/$_" } @noDotFiles;
} else {
  $files[0] = $inputFileOrDir;
}

my $unflattener = Bio::SeqFeature::Tools::Unflattener->new();

foreach my $file (@files) {
  my $bioperlSeqIO;

  if ($inputFormat =~ m/^gff([2|3])$/i) {
    $bioperlSeqIO = &convertGFFStreamToSeqIO($file,$1,$gff2GroupTag);
  } else {
    $bioperlSeqIO = Bio::SeqIO->new(-format => $inputFormat,   -file   => $file);
  }

  if ($outputFormat =~ /gff/i ) {
    my $gff = FileHandle->new();
    $gff->open (">$outputFile") || die "can not open gffOutput file to write\n";
    $gff->print ("##gff-version 3\n");
    $gff->print ("##date-created at ".localtime()."\n");
    processInputFile ($gff, $bioperlSeqIO);
    $gff->close;
  } else {
    print STDERR "output format has not been configured yet\n";
  }
}

sub processInputFile {
  my ($fH, $bioperlSeqIO) = @_;
  while (my $bioperlSeq = $bioperlSeqIO->next_seq() ) {
    if ($unflatten && ( ($inputFormat =~/genbank/i ) || ($inputFormat =~ /embl/i ) ) ) {
      $unflattener->unflatten_seq(-seq => $bioperlSeq,
				  -use_magic => 1);
    }

    my $seqId = $bioperlSeq->id;
    my $sequence = $bioperlSeq->seq;

    foreach my $bioperlFeature ($bioperlSeq->get_SeqFeatures()) {
      processFeature($fH, $seqId, $bioperlFeature, "root");
    }
    if ($outputFormat =~ /gff/i) {
      $fH->print ("##FASTA\n");
      $fH->print (">$seqId\n");
      $fH->print ($bioperlSeq->seq."\n");
    }
  }
}

sub processFeature {
  my ($fH, $seqId, $bioperlFeature, $parent) = @_;

  if ($outputFormat =~ /gff3/i) {
    printGFF($fH, $seqId, $bioperlFeature);
  }
}

sub printGFF {
  my ($gff, $seqId, $bioperlFeature) = @_;


  my $type = $bioperlFeature->primary_tag();

  my $id;
  if ($bioperlFeature->has_tag('ID')) {
    ($id) = $bioperlFeature->get_tag_values('ID');
  } elsif ($bioperlFeature->has_tag('locus_tag')) {
    ($id) = $bioperlFeature->get_tag_values('locus_tag');
  } elsif ($bioperlFeature->has_tag('origid')) {
    ($id) = $bioperlFeature->get_tag_values('origid');
  } else {
    print STDERR "in '$type', \$id has not configured yet\n";
  }


  if ($type eq "CDS") {  ## print gene structure
    printGene($gff, $seqId, $id, $bioperlFeature);
    printTranscript($gff, $seqId, $id, $bioperlFeature);
    printCDS($gff, $seqId, $id, $bioperlFeature);

  } else {  ## print others
    my @items;
    $items[0] = $seqId;
    $items[1] = "Artemis";
    $items[2] = $type;
    $items[3] = $bioperlFeature->location->start;
    $items[4] = $bioperlFeature->location->end;
    $items[5] = ".";
    $items[6] = ($bioperlFeature->strand == 1) ? "+" : "-";
    $items[7] = ($type eq "CDS") ? 0 : ".";
    $items[8] = "ID=$id;";

    &printGff3Column ($gff, \@items);
  }

}

sub printGene {
  my ($gff, $seqId, $id, $bioperlFeature) = @_;

  my $type = "gene";
  my $frame = ".";

  my @items;
  $items[0] = $seqId;
  $items[1] = "Artemis";
  $items[2] = $type;
  $items[3] = $bioperlFeature->location->start;
  $items[4] = $bioperlFeature->location->end;
  $items[5] = ".";
  $items[6] = ($bioperlFeature->strand == 1) ? "+" : "-";
  $items[7] = $frame;
  $items[8] = "ID=$id;";

  &printGff3Column ($gff, \@items);
}

sub printTranscript {
  my ($gff, $seqId, $id, $bioperlFeature) = @_;

  my $type = "mRNA";
  my $frame = ".";
  my $transId = $id.".mRNA";

  my @items;
  $items[0] = $seqId;
  $items[1] = "Artemis";
  $items[2] = $type;
  $items[3] = $bioperlFeature->location->start;
  $items[4] = $bioperlFeature->location->end;
  $items[5] = ".";
  $items[6] = ($bioperlFeature->strand == 1) ? "+" : "-";
  $items[7] = $frame;
  $items[8] = "ID=$transId;Parent=$id";

#  foreach my $qualifier ($bioperlFeature->get_all_tags()) {
#    if ($qualifier =~ /product/i || $qualifier =~ /note/i
#	|| $qualifier =~ /partial/i ) {
#      my ($tagVal) = $bioperlFeature->get_tag_values($qualifier);
#      $tagVal = "$qualifier=$tagVal";
#      $items[8] .= $tagVal . ";";
#    }
#  }

  &printGff3Column ($gff, \@items);  
}

sub printCDS {
  my ($gff, $seqId, $id, $bioperlFeature) = @_;

  my $type = "CDS";
  my $frame = 0;
  my $transId = $id.".mRNA";

  my @cdsLocs = $bioperlFeature->location->each_Location();

  my $cdsCount = 1;
  foreach my $cdsLoc (@cdsLocs) {
    my $cdsId = $id.".cds".$cdsCount;

    my @items;
    $items[0] = $seqId;
    $items[1] = "Artemis";
    $items[2] = $type;
    $items[3] = $cdsLoc->start();
    $items[4] = $cdsLoc->end();
    $items[5] = ".";
    $items[6] = ($bioperlFeature->strand == 1) ? "+" : "-";
    $items[7] = $frame;
    $items[8] = "ID=$cdsId;Parent=$transId;";

    &printGff3Column ($gff, \@items);  

    $cdsCount++;
  }

}

sub printGff3Column {
  my ($fileH, $array) = @_;
  foreach my $i (0..$#{$array}) {
    ($i == 8) ? $fileH->print ("$array->[$i]\n") : $fileH->print ("$array->[$i]\t");
  }
  return 0;
}


sub usage {
  die
"
Convert annotation file format

Usage: 

where
  --inputFormat:       embl, genbank, tigr (or any format supported by bioperl's SeqIO)
  --inputFileOrDir:    a seq/feature file, or a directory containing a set of them
  --outputFormat:  gff3, embl, genbank
  --outputFile:  the output file name
  --unflatten  if present, use bioperl's unflattener (only applicable
                to genbank and embl)
  --gff2Group  if present, specify gff2 group tag (only applicable
                to gff2)
";
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
