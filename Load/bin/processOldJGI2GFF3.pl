#!/usr/bin/perl -w
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
  # GUS4_STATUS | dots.gene                      | manual | unreviewed
die 'This file has broken or unreviewed GUS4_STATUS rules.  Please remove this line when all are fixed or absent';
#^^^^^^^^^^^^^^^^^^^^^^^^^ End GUS4_STATUS ^^^^^^^^^^^^^^^^^^^^

# The annotation output files for older JGI genomes were in a different format
# This script converts the older JGI gtf into ISF compatible format.
# Input arg 1-> GTF file
# Input arg 2-> Prefix for the genus
# Author: Sucheta
 
open FH, $ARGV[0] or die "Can't open file for reading $! \n";

my $prefix = $ARGV[1];
my $exon;

while(<FH>){

	chomp;
	my @tmp=split(/\t/,$_);
	my $strand = $tmp[2];
	my $scaffold=$tmp[1];
	my $geneStart=$tmp[3];
	my $geneStop=$tmp[4];
	my $exonNum=$tmp[7];
	my $startCodon=$tmp[5];
	my $endCodon=$tmp[6];
	my @exonStart=split(/\,/,$tmp[8]);
	my @exonEnd=split(/\,/,$tmp[9]);
	my $geneId;


	if(!$strand ||
	!$scaffold  ||
	!$geneStart ||
	!$geneStop  ||
	!$exonNum   ||
	!$startCodon||
	!$endCodon  ||
	!scalar(@exonStart) ||
	!scalar(@exonEnd) ){
		next;
	}	
	
	if($tmp[10] =~ /id=(\d+)/){
		$geneId=$1;
	}	

		print "$scaffold\tJGI\tgene\t$geneStart\t$geneStop\t.\t$strand\t.\tID \"$prefix$geneId\";\n";
	
		print "$scaffold\tJGI\tmRNA\t$geneStart\t$geneStop\t.\t$strand\t.\tID \"$prefix$geneId"."T0\"; Parent \"$prefix$geneId\";\n";



	for(my $i=0;$i<$exonNum;$i++){

		$exon = $i+1;
		
		if($i==0){
	
			print "$scaffold\tJGI\texon\t$exonStart[$i]\t$exonEnd[$i]\t.\t$strand\t.\tID \"$prefix$geneId.$exon:exon\"; Parent \"$prefix$geneId"."T0\"; \n";
			print "$scaffold\tJGI\tCDS\t$startCodon\t$exonEnd[$i]\t.\t$strand\t.\tID \"$prefix$geneId.$exon:CDS\"; Parent \"$prefix$geneId"."T0\"; \n";
		}
		
		else{
		
			print "$scaffold\tJGI\texon\t$exonStart[$i]\t$exonEnd[$i]\t.\t$strand\t.\tID \"$prefix$geneId.$exon:exon\"; Parent \"$prefix$geneId"."T0\"; \n";
			print "$scaffold\tJGI\tCDS\t$exonStart[$i]\t$exonEnd[$i]\t.\t$strand\t.\tID \"$prefix".$geneId.".$exon:CDS\"; Parent \"$prefix$geneId"."T0\"; \n";
		}
	}	

		print "$scaffold\tJGI\tstart_codon\t$startCodon\t", $startCodon+2 ,"\t.\t$strand\t.\tID \"start_$geneId.1\"; Parent \"$prefix$geneId"."T0\"; \n";
		print "$scaffold\tJGI\tstop_codon\t",$endCodon,"\t$geneStop\t.\t$strand\t.\tID \"stop_$geneId.1\"; Parent \"$prefix$geneId"."T0\"; \n";

}

close(FH);

