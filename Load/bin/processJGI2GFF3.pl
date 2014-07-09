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

# This script converts JGI jff into ISF compatible format
# Takes 2 arguments, 1. Is the gff file 2. Is the gene prefix
# Example: perl JGIToISFGFF.pl <filename> <Physo_> > output
# Author: Sucheta
 

my %HOH = &readJGIgff($ARGV[0]);
my %geneHash;

my $exon_num;
my $cds_num;
my $prefix=$ARGV[1];
my $lengthThreshold=50000;

for my $scaffold(keys %HOH){
	
	for my $gene(keys %{$HOH{$scaffold}}){

		my $comment='';
	
		
		$exon_num=1;
		$cds_num=1;
		my (@start, @stop, @exon, @CDS);

		if(exists $HOH{$scaffold}{$gene}{'start_codon'}){
			
			@start = sort{$a <=> $b} @{ $HOH{$scaffold}{$gene}{'start_codon'}};
		}
		if(exists $HOH{$scaffold}{$gene}{'stop_codon'}){
		
			@stop = sort{$a <=> $b} @{ $HOH{$scaffold}{$gene}{'stop_codon'}};
		}
		if(exists $HOH{$scaffold}{$gene}{'exon'}){
		
			@exon = sort{$a <=> $b} @{ $HOH{$scaffold}{$gene}{'exon'}};
		}
		if(exists $HOH{$scaffold}{$gene}{'CDS'}){
		
			@CDS = sort{$a <=> $b} @{ $HOH{$scaffold}{$gene}{'CDS'}};
		}
		
		#Check if gene is longer than threshold then comment that line
		
		if(($exon[-1] - $exon[0]) > $lengthThreshold){
			$comment="#";
		}

		my $geneName = $HOH{$scaffold}{$gene}{'geneid'};

		print "$comment$scaffold\tJGI\tgene\t$exon[0]\t$exon[-1]\t.\t$HOH{$scaffold}{$gene}{'strand'}\t.\tID \"$prefix$geneName\";\n";
		
		print "$comment$scaffold\tJGI\tmRNA\t$exon[0]\t$exon[-1]\t.\t$HOH{$scaffold}{$gene}{'strand'}\t.\tID \"$prefix$geneName"."T0\"; Parent \"$prefix$geneName\";\n";
		if($start[0]){
		
			print "$comment$scaffold\tJGI\tstart_codon\t$start[0]\t$start[1]\t.\t$HOH{$scaffold}{$gene}{'strand'}\t.\tID \"start_$geneName.1\"; Parent \"$prefix$geneName"."T0\";\n";
		}

		for(my $i=0;$i<$#exon;$i+=2){

				
			print "$comment$scaffold\tJGI\texon\t$exon[$i]\t$exon[$i+1]\t.\t$HOH{$scaffold}{$gene}{'strand'}\t.\tID \"$prefix$geneName.$exon_num:exon\"; Parent \"$prefix$geneName"."T0\";\n";
			
			
			if($CDS[$i]){	
				
				print "$comment$scaffold\tJGI\tCDS\t$CDS[$i]\t$CDS[$i+1]\t.\t$HOH{$scaffold}{$gene}{'strand'}\t.\tID \"$prefix$geneName.$cds_num:CDS\"; Parent \"$prefix$geneName"."T0\";\n";
			$cds_num++;

			}
			$exon_num++;

		}
		
		if($stop[0]){
		
			print "$comment$scaffold\tJGI\tstop_codon\t$stop[0]\t$stop[1]\t.\t$HOH{$scaffold}{$gene}{'strand'}\t.\tID \"stop_$geneName.1\"; Parent \"$prefix$geneName"."T0\";\n";
		}

	}


}	
			

sub readJGIgff{

my $fileName = shift;
my %HOH;
my %geneNameHash;

open PRED, $fileName or die "Can't open file $!\n";
my $prevName;
my $num;
my @arr;

# Modify the name string in the gff. Since the name string is NOT uniq 
# This block modifies, so that name remains unique

while(<PRED>){
        chomp;
        my $name;
        if(/name\s+\"(.*?)\"/){
                $name = $1;
                if($name !~ $prevName){
                        $num++;
                }
                $prevName=$name;
                my $tmp = $name."_$num";
        my @tmparr = split(/\t/,$_);
        $tmparr[-1]  =~ s/$name/$tmp/;
        my $line = join("\t",@tmparr);
        push @arr, $line;
        }
}
		
close(PRED);

foreach my $line(@arr){
	
	my $gene_id;
	
	my $name;
	

	if($line =~ /name\s+\"(\S+)\";\s+transcriptId\s+(\d+)/){
	
		$name    = $1;
		$gene_id = $2;
		

		$geneNameHash{$name}=$gene_id;
	}


}

# The names are not uniq in some species, so increment names each time it
# encounters a new block;

foreach my $tmp (@arr){

	if($tmp =~ /^#/){
		next;
	}	
	
		
		my @line = split(/\t/,$tmp);
		
		my $last = scalar(@line) - 1;
		
		my $name;

		
		if($line[$last] =~ /name\s+\"(\S+)\"/){
			$name =$1;
		}
		
		$line[$last] = $name;		
			
			if($tmp =~ /start_codon/i){
			
				push(@{$HOH{$line[0]}->{$line[$last]}->{'start_codon'}}, $line[3], $line[4]);
			}
			elsif($tmp =~ /stop_codon/i){
				push(@{$HOH{$line[0]}->{$line[$last]}->{'stop_codon'}}, $line[3], $line[4]);
			}
			elsif($tmp =~/CDS/i){

				push(@{$HOH{$line[0]}->{$line[$last]}->{'CDS'}}, $line[3], $line[4]);
			}
			elsif($tmp =~/exon/i){

				push(@{$HOH{$line[0]}->{$line[$last]}->{'exon'}}, $line[3], $line[4]);
			}
		
		$HOH{$line[0]}->{$line[$last]}->{'strand'} = $line[6];

		$HOH{$line[0]}->{$line[$last]}->{'score'} = $line[5];
		
		$HOH{$line[0]}->{$line[$last]}->{'geneid'} = $geneNameHash{$line[$last]};



}

return %HOH;

}
