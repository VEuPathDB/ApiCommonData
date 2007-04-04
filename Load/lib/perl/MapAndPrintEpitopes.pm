package ApiCommonData::Load::MapAndPrintEpitopes;

use lib "$ENV{GUS_HOME}/lib/perl";
use Getopt::Long;
use Switch;
use strict;

sub mapEpitopes{
  my ($subjSeq, $subId, $seqId, $epitopes, $outFile, $debug) = @_;

      print STDERR "Getting epitopes...\n" if $debug;

      my $foundAll = 1;
      foreach my $epitope (keys %{$$epitopes{$seqId}}){

	my ($start, $end) = &_getLocation($$epitopes{$seqId}->{$epitope}->{seq}, $subjSeq);

	if ($start && $end) {
	  $$epitopes{$seqId}->{$epitope}->{start} = $start;
	  $$epitopes{$seqId}->{$epitope}->{end} = $end;
	}else{
	  $foundAll = 0;
	  print STDERR "EPITOPE '$epitope' NOT FOUND IN SEQ '$subId'\n" if($$epitopes{$seqId}->{$epitope}->{blastHit});
	}
      }

      ##output the results into a file that you can load with plugin
      &_printResultsToFile($seqId, $subId, $epitopes, $outFile, $foundAll);
}

sub makeEpitopeHash{
  my ($epitopeFile,$epitopes) = @_;

  print STDERR "Generating epitope hash from file...\n";

  open (FILE, $epitopeFile) || die "Could not open file '$epitopeFile':$!'";

  while (<FILE>){
    chomp;

    my @data = split('\t',$_);

    next if ($data[0] eq 'Accession');

    $$epitopes{$data[0]}->{$data[1]} =  ({seq => $data[3],
					      strain => $data[2],
					      name => $data[4]
					     });
  }
}

sub _getLocation{
  my ($epiSeq, $subSeq) = @_;
  my $start;
  my $end;

  if($subSeq =~ /$epiSeq/i){
    ($start) = @-; #@- holds one before the start of match
    $start ++;
    ($end) = @+; #@+ holds the end of match

  }
return ($start,$end);
}

sub _printResultsToFile{
  my ($seqId, $subId, $epitopes, $outFile, $foundAll) = @_;

  my $dbRefOutFile = $outFile;
  $dbRefOutFile =~ s/\.out/Refs.txt/;

  foreach my $iedbId (keys %{$$epitopes{$seqId}}){

      my $name = $epitopes->{$seqId}->{$iedbId}->{name};
      my $start = $epitopes->{$seqId}->{$iedbId}->{start};
      my $end = $epitopes->{$seqId}->{$iedbId}->{end};
      my $strain = $epitopes->{$seqId}->{$iedbId}->{strain};
      my $blastHit = 0;
      if($$epitopes{$seqId}->{$iedbId}->{blastHit}){
	$blastHit = 1;
      }

      if($start && $end){
	open(OUT,">>$outFile") || die "Could not open '$outFile' for appending:$!\n";

	print OUT "$subId\t$iedbId\t$name\t$start\t$end\t$strain\t$blastHit\t$foundAll\n";

	close(OUT);

	open (REFOUT, ">>$dbRefOutFile") || die "Could not open '$dbRefOutFile' for appending: $!\n";

	print REFOUT "$iedbId\t$iedbId\t$strain\n";

	close(REFOUT);
      }
    }
}

1;
