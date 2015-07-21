package ApiCommonData::Load::MultAlignMercatorMavid;
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

use strict;

use Bio::SeqIO;
use Bio::Seq;

#use ApiCommonWebsite::Model::ModelProp;

use Data::Dumper;

use CGI::Carp qw(fatalsToBrowser set_message);


# ========================================================================
# ----------------------------- BEGIN Block ------------------------------
# ========================================================================
BEGIN {
    # Carp callback for sending fatal messages to browser
    sub handle_errors {
        my ($msg) = @_;
#        print "<p><pre>$msg</pre></p>";
    }
    set_message(\&handle_errors);
}

#--------------------------------------------------------------------------------

sub new {
	 my $Class = shift;

	 my $Self = bless {}, $Class;

	 return $Self;
}

#--------------------------------------------------------------------------------


sub getAlignmentLocations {
  my($self,$contig, $start, $stop, $strand) = @_;

  my $agpDir = $self->getMercatorOutputDir();
  my $alignDir = $self->getMercatorOutputDir()."/alignments";
  my $sliceAlign = $self->getCndSrcBin()."/sliceAlignment";
  my $fa2clustal = $self->getCndSrcBin()."/fa2clustal";

  my ($genome, $assembly, $assemblyStart, $assemblyStop, $assemblyStrand) = &translateCoordinates($contig, $agpDir, $start, $stop, $strand);

  my $locations = &getLocations($alignDir, $agpDir, $sliceAlign, $genome, $assembly, $assemblyStart, $assemblyStop, '+');

  return $locations;
}

#--------------------------------------------------------------------------------
sub initialize {
  my($self,$dbh,$mod,$csb) = @_;
  $self->setCndSrcBin($csb);
  $self->setMercatorOutputDir($mod);
  $self->setDbh($dbh);
}

sub setCndSrcBin { my($self,$val) = @_; $self->{CndSrcBin} = $val; }
sub getCndSrcBin { my $self = shift; return $self->{CndSrcBin}; }

sub setDbh { my($self,$val) = @_; $self->{dbh} = $val; }
sub getDbh { my $self = shift; return $self->{dbh}; }

sub setMercatorOutputDir { my($self,$dir) = @_; $self->{MercatorOutputdir} = $dir; }
sub getMercatorOutputDir { my $self = shift; return $self->{MercatorOutputdir}; }
#--------------------------------------------------------------------------------

sub translateCoordinates {
  my ($contig, $agpDir, $start, $stop, $strand) = @_;

  opendir(DIR, $agpDir) or &error("Could not open directory $agpDir for reading:$!");

  my ($genome, $assembly);

  while (defined (my $fn = readdir DIR) ) {
    next unless($fn =~ /(.+)\.agp$/);

    my $thisGenome = $1;

    open(AGP, "$agpDir/$fn") or &error("Cannot open file $fn for reading: $!");

    while(<AGP>) {
      chomp;
      my @a = split(/\t/, $_);
      my $assemblyName = $a[0];
      my $assemblyStart = $a[1];
      my $assemblyStop = $a[2];
      my $contigName = $a[5];
      my $contigStart = $a[6];
      my $contigStop = $a[7];
      my $contigStrand = $a[8];

      next unless($contigName eq $contig);

      if($genome) {
        &error("Source_id $contig was found in multiple genomes: $genome and $thisGenome");
      }
      $genome = $thisGenome;
      $assembly = $assemblyName;

      if($start > $contigStop || $stop < $contigStart) {
        &userError("Please enter coordinates between $contigStart-$contigStop for $contig");
      }

      # The -1 is because sliceAlign has a 1 off error
      if($contigStrand eq '+') {
        $start = $assemblyStart + ($start - $contigStart) - 1;
        $stop = $assemblyStop - ($contigStop - $stop);
      }
      else {
        my $tmpStop = $stop;
        $stop = $assemblyStop - ($start - $contigStart);
        $start = $assemblyStart +  ($contigStop - $tmpStop) -  1;
        $strand = $strand eq '+' ? '-' : '+';
      }
    }
    close AGP;
  }
  close DIR;

  unless($genome) {
    &userError("$contig was not found in any of the genomes which were input to mercator.\n\nUse the chromosome id for scaffolds which have been assembled into chromosomes");
  }
  return($genome, $assembly, $start, $stop, $strand);
}

#--------------------------------------------------------------------------------



sub getNewLocations {
  my ($agpDir, $genome, $input, $start, $stop, $strand) = @_;

  my $fn = "$agpDir/$genome" . ".agp";

  open(FILE, $fn) or error("Cannot open file $fn for reading:$!");

  my @v;

  while(<FILE>) {
    chomp;

    my @ar = split(/\t/, $_);

    my $assembly = $ar[0];
    my $assemblyStart = $ar[1];
    my $assemblyStop = $ar[2];
    my $type = $ar[4];

    my $contig = $ar[5];
    my $contigStart = $ar[6];
    my $contigStop = $ar[7];
    my $contigStrand = $ar[8];

    next unless($type eq 'D');
    my $shift = $assemblyStart - $contigStart;
    my $checkShift = $assemblyStop - $contigStop;

    &error("Cannot determine shift") unless($shift == $checkShift);

    if($assembly eq $input && 
       (($start >= $assemblyStart && $start <= $assemblyStop) || 
        ($stop >= $assemblyStart && $stop <= $assemblyStop) ||
        ($start < $assemblyStart && $stop > $assemblyStop ))) {
      
      my ($newStart, $newStop, $newStrand);

      # the +1 and -1 is because of a 1 off error in the sliceAlign program
      if($contigStrand eq '+') {
        $newStart = $start < $assemblyStart ? $contigStart : $start - $assemblyStart + $contigStart + 1;
        $newStop = $stop > $assemblyStop ? $contigStop : $stop - $assemblyStart + $contigStart; 
        $newStrand = $strand;
      }
      else {
        $newStart = $start < $assemblyStart ? $contigStop : $assemblyStop - $start + $contigStart - 1;
        $newStop = $stop > $assemblyStop ? $contigStart : $assemblyStop - $stop + $contigStart;  
        $newStrand = $strand eq '+' ? '-' : '+';
      }

      if($newStart <= $newStop) {
        push(@v, [$contig,$newStart,$newStop,$newStrand]);
      }
      else {
        push(@v, [$contig,$newStop,$newStart,$newStrand]);
      }
    }
  }
  close FILE;

  return \@v;
}

#--------------------------------------------------------------------------------

sub getLocations {  ##get the locations and identifiers of all toxo seqs
  my ($alignDir, $agpDir, $sliceAlign, $referenceGenome, $queryContig, $queryStart, $queryStop, $queryStrand) = @_;


  my $command = "$sliceAlign $alignDir $referenceGenome '$queryContig' $queryStart $queryStop $queryStrand";
 
  my @lines = `$command`;

  my @locs;

  foreach my $line (@lines) {
    my ($genome, $assembled, $start, $stop, $strand) = $line =~ />(\S+) (\S+):(\d+)-(\d+)([\-+])/;

    next unless($genome);

    my $loc = &getNewLocations($agpDir, $genome, $assembled, $start, $stop, $strand);

    push(@locs,@$loc);

  }

  return \@locs;
}  
#--------------------------------------------------------------------------------

#--------------------------------------------------------------------------------

sub error {
  my ($msg) = @_;

  print STDERR "ERROR: $msg\n\nPlease report this error.  \nMake sure to include the error message, contig_id, start and end positions.\n";
}

sub userError {
  my ($msg) = @_;

  print STDERR "$msg\n\nPlease Try again!\n";
}

1;
