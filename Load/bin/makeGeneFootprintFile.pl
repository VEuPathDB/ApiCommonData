#!/usr/bin/perl

use strict;
use warnings;
use lib "$ENV{GUS_HOME}/lib/perl";
use Getopt::Long;
use GUS::ObjRelP::DbiDatabase;
use CBIL::Util::PropertySet;
use GUS::Community::GeneModelLocations;
use File::Basename;
use Data::Dumper;

my ($gusConfigFile,$verbose,$outFile,$project,$genomeExtDbRlsSpec,$soTermName,$soExclude);
&GetOptions("verbose!"=> \$verbose,
            "outputFile=s" => \$outFile,
            "gusConfigFile=s" => \$gusConfigFile,
            "project=s" => \$project,
            "genomeExtDbRlsSpec=s" => \$genomeExtDbRlsSpec,
            "sequence_ontology_term=s" => \$soTermName,
            "so_exclude" => \$soExclude
    ); 

if(!$outFile || !$project || !$genomeExtDbRlsSpec){
	die "usage: makeGeneFootprintFile.pl --outputFile <outfile> --verbose --gusConfigFile [\$GUS_CONFIG_FILE] --project 'TriTrypDB, PlasmoDB etc to show origin of data' --genomeExtDbRlsSpec genomeExtDbRlsSpec\n";
}

##Create db handle
if(!$gusConfigFile) {
  $gusConfigFile = $ENV{GUS_HOME} . "/config/gus.config";
  
}

my @properties = ();

print STDERR "Establishing dbi login\n" if $verbose;
die "Config file $gusConfigFile does not exist." unless -e $gusConfigFile;

my $gusconfig = CBIL::Util::PropertySet->new($gusConfigFile, \@properties, 1);

my $db = GUS::ObjRelP::DbiDatabase->new($gusconfig->{props}->{dbiDsn},
                                        $gusconfig->{props}->{databaseLogin},
                                        $gusconfig->{props}->{databasePassword},
					$verbose,0,1,
					$gusconfig->{props}->{coreSchemaName},
				       );

my $dbh = $db->getQueryHandle();

open(OUT,">$outFile");
print OUT ("PROJECT\tGENE\tFOOTPRINT_LENGTH\tCHROMOSOME\tFOOTPRINT_SPANS\n");

my $genomeExtDbRlsId = &getExtDbRlsIdFromSpec($dbh, $genomeExtDbRlsSpec);


my $geneModelLocations = GUS::Community::GeneModelLocations->new($dbh, $genomeExtDbRlsId, 1, $soTermName, $soExclude);
my @geneSourceIds = sort @{$geneModelLocations->getAllGeneIds()};

my $maxIntronLen = 0;

foreach my $geneSourceId (@geneSourceIds) {
    my $seqId;
    my $exons;
    my $feature = $geneModelLocations->bioperlFeaturesFromGeneSourceId($geneSourceId);
    
    foreach my $subFeature (@{$feature}) {
        if ($subFeature->primary_tag() eq 'exon'){
            if (!defined($seqId)) {
                $seqId = $subFeature->seq_id(); 
            }
            elsif ($seqId ne $subFeature->seq_id()) {
                die "More than one sequence_id for gene $geneSourceId\n";
            }
            my $start = $subFeature->start();
            my $end = $subFeature->end();
            push(@{$exons}, "$start\t$end");
        }

        elsif(GUS::Community::GeneModelLocations::getShortFeatureType($subFeature) eq 'Transcript') {
            foreach my $intron ($subFeature->introns()) {
                my $intronLocation = $intron->location();
                my $intronLength = abs($intronLocation->end() - $intronLocation->start());
                $maxIntronLen = ($intronLength > $maxIntronLen) ? $intronLength : $maxIntronLen;
            }
        }
    }
    printFootprint($project, $geneSourceId, $seqId, $exons);
}
$maxIntronLen = $maxIntronLen * 1.5;
$maxIntronLen = ($maxIntronLen > 500000) ? 500000 : $maxIntronLen;
$maxIntronLen = int($maxIntronLen + 0.5);
printIntronLen($maxIntronLen, $outFile);

##subroutines

sub getExtDbRlsIdFromSpec {
  my ($dbh, $genomeExtDbRlsSpec) = @_;

  my ($name, $version) = split(/\|/, $genomeExtDbRlsSpec);

  my $sql = "select r.external_database_release_id 
from sres.externaldatabase d
   , sres.externaldatabaserelease r
where d.EXTERNAL_DATABASE_ID = r.EXTERNAL_DATABASE_ID
and d.name = ?
and r.version = ?";

  my $sh = $dbh->prepare($sql);
  $sh->execute($name, $version);

  my ($count, $rv);

  while(my ($id) = $sh->fetchrow_array()) {
    $rv =  $id;
    $count++;
  }

  $sh->finish();

  if($count != 1) {
    die "Could not find an external database release id for the spec $genomeExtDbRlsSpec";
  }

  return $rv;
}
    
sub printFootprint {
    my ($project, $geneSourceId, $seqId, $exons) = @_;
    my @distinctExons;
    my %countedExons;
    for (my $i=0 ;$i<@{$exons}; $i++) {
	if (!$countedExons{$exons->[$i]}) {
	    push(@distinctExons, $exons->[$i]);
	    $countedExons{$exons->[$i]} = 1;
	} 
    }
    my @sortedExons = sort exonSort @distinctExons;
    my @footprintStarts;
    my @footprintEnds;
    my ($currentStart, $currentEnd) = split(/\t/, $sortedExons[0]);
    for (my $i=1; $i<@sortedExons; $i++) {
	my ($nextStart, $nextEnd) = split(/\t/, $sortedExons[$i]);
	if ($currentEnd<$nextStart) {
	    push(@footprintStarts, $currentStart);
	    push(@footprintEnds, $currentEnd);
	    $currentStart = $nextStart;
	    $currentEnd = $nextEnd;
	}
	elsif ($currentEnd<=$nextEnd) {
	    $currentEnd = $nextEnd;
	}
	else {
	}
    }
    push (@footprintStarts, $currentStart);
    push(@footprintEnds, $currentEnd);
    
    my $length = 0;
    my $span = '';
    for (my $i=0; $i<@footprintStarts; $i++) {
	$length += $footprintEnds[$i]-$footprintStarts[$i]+1;
	$span .= "$footprintStarts[$i]-$footprintEnds[$i]";
	if ($i<@footprintStarts-1) {
	    $span .= ";";
	}
    }
    print OUT ("$project\t$geneSourceId\t$length\t$seqId\t$span\n");
}

sub printIntronLen {
    my ($maxIntronLen, $outFile) = @_;
    my $dir = dirname($outFile);
    open(INTRON,">$dir/maxIntronLen");
    print INTRON $maxIntronLen;
    close(INTRON);
}

sub exonSort {
  my ($aStart, $aEnd) = split(/\t/, $a);
  my ($bStart, $bEnd) = split(/\t/, $b);
  return ($aStart<=>$bStart or $aEnd<=>$bEnd);
}
    
close (OUT);
exit;
