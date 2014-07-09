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

# Input => parameter1 => ISF tested GFF file
# Input => parameter2 => a fasta genome file
# Return => file1  => Hard coded as 'transcriptSeq' => returns the transcript se
# quence in fasta format
# Return => file2  => hard coded as 'proteinSeq' => returns the protein sequence
# in fasta format
# Date: 6th March 2012
# Author: Sucheta
 

my %HOH = &readISFgff($ARGV[0]);
my %seq = &read_fasta_tohash($ARGV[1]);
my %geneHash;

my $exon_num;
my $cds_num;
my $prefix=$ARGV[1];
my $lengthThreshold=50000;

open FH, ">transcriptSeq" or die "Can't open file for writing $! \n";

open FH1, ">proteinSeq" or die "Can't open transcript sequence file for writing $! \n";

for my $scaffold(keys %HOH){
	
	for my $gene(keys %{$HOH{$scaffold}}){

		my (@CDS);

		if(exists $HOH{$scaffold}{$gene}{'CDS'}){
		
			@CDS = sort{$a <=> $b} @{ $HOH{$scaffold}{$gene}{'CDS'}};
			if(($CDS[-1] - $CDS[0]) > $lengthThreshold){
				next;
			}
		
		#Check if gene is longer than threshold then comment that line
		

		my $transcript;

		for(my $i=0;$i<scalar(@CDS);$i+=2){

		my $length=$CDS[$i+1] - $CDS[$i] + 1;

		$transcript.=substr($seq{$scaffold},$CDS[$i]-1,$length);
		}

		if($HOH{$scaffold}{$gene}{'strand'} eq '-'){
		my $tmp=&reverse_complement(\$transcript);
		$transcript = $tmp;

		}

		my $proteinSeq=&translate($transcript);

		print FH ">$gene\n$transcript\n";
		print FH1 ">$gene\n$proteinSeq\n";

		}


	}


}	
			
close(FH);
close(FH1);


sub readISFgff{

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



	if(/^#/){
		next;
	}	
	
		
		my $gene_id;
		my @line=split(/\t/,$_);

		if(/Parent\s+\"(\S+)\"/){
			$gene_id = $1;
		}
		else{ next; }

	
		
			
		if(/CDS/i){

		push(@{$HOH{$line[0]}->{$gene_id}->{'CDS'}}, $line[3], $line[4]);
		}
		
		$HOH{$line[0]}->{$gene_id}->{'strand'} = $line[6];

		$HOH{$line[0]}->{$gene_id}->{'score'} = $line[5];
		


}

close(PRED);

return %HOH;

}



##### Translate a given DNA sequence into protein
# Input a DNA string and 3 other optional parameters
# Added 2 other parameters. 1) position from where
# translation will begin and
# 2) length of DNA to be translated

sub translate{
     my $dna = shift;
     my $start = shift;
     my $len = shift;
         my $format = shift; # if 1 do formatting else print in just one line

         if(!$start){$start=0;}
         if(!$len){$len=length($dna);}
        if(!$format){$format = 0; }

         my $prot ='';
     my $i=$start;
     my $j=1;
     my $codon;

        $len += $start;

        for(;$i<$len;$i+=3,$j++){
          # Adding newline every 60th character
                if($format == 1){
                        if(($j == 44) || !($j%57)){
                $j = 57;  # set $j equal to 58 so it will not wrap at 44 again
                $prot .="\n";  # Here single quote does not work
                $prot .= "                     ";
                }
                }
           $codon = substr($dna,$i,3);

        if ( $codon =~ /GC./i)        { $prot .=  'A'; }     # Alanine
     elsif ( $codon =~ /TG[TC]/i)     { $prot .=  'C'; }     # Cysteine
     elsif ( $codon =~ /GA[TC]/i)     { $prot .=  'D'; }     # Aspartic Acid
     elsif ( $codon =~ /GA[AG]/i)     { $prot .=  'E'; }     # Glutamic Acid
     elsif ( $codon =~ /TT[TC]/i)     { $prot .=  'F'; }     # Phenylalanine
     elsif ( $codon =~ /GG./i)        { $prot .=  'G'; }     # Glycine
     elsif ( $codon =~ /CA[TC]/i)     { $prot .=  'H'; }     # Histidine
     elsif ( $codon =~ /AT[TCA]/i)    { $prot .=  'I'; }     # Isoleucine
     elsif ( $codon =~ /AA[AG]/i)     { $prot .=  'K'; }     # Lysine
     elsif ( $codon =~ /TT[AG]|CT./i) { $prot .=  'L'; }     # Leucine
     elsif ( $codon =~ /ATG/i)        { $prot .=  'M'; }     # Methionine
     elsif ( $codon =~ /AA[TC]/i)     { $prot .=  'N'; }     # Asparagine
     elsif ( $codon =~ /CC./i)        { $prot .=  'P'; }     # Proline
     elsif ( $codon =~ /CA[AG]/i)     { $prot .=  'Q'; }     # Glutamine
     elsif ( $codon =~ /CG.|AG[AG]/i) { $prot .=  'R'; }     # Arginine
     elsif ( $codon =~ /TC.|AG[TC]/i) { $prot .=  'S'; }     # Serine
     elsif ( $codon =~ /AC./i)        { $prot .=  'T'; }     # Threonine
     elsif ( $codon =~ /GT./i)        { $prot .=  'V'; }     # Valine
     elsif ( $codon =~ /TGG/i)        { $prot .=  'W'; }     # Tryptophan
     elsif ( $codon =~ /TA[TC]/i)     { $prot .=  'Y'; }     # Tyrosine
     elsif ( $codon =~ /TA[AG]|TGA/i) { $prot .=  '*'; }     # Stop
     else { $prot .=  '-'; }     # unknown

     }
return $prot;
}

###### End of Translation Function #####


################ Beginning of read_fasta_tohash  ######################

# this function reads a sequence file in fasta format and stores
# it as a perl hash

sub read_fasta_tohash{

my $file_name=shift;
open SCAF, $file_name or die "can't open file $!\n";
my %scaf=();
my $id = "";
my $sequence = "";
my $first_pass=1;

while(<SCAF>){  #Reading the file
        if($_ =~ /^>(.*)/){
            if( not $first_pass){
                $scaf{$id}=$sequence; #second time the > symbol encountered
            }
            $id = $1;
            chomp($id);
            $first_pass=0;
            $sequence="";
        }
        else{
            chomp($_);
            $sequence .= $_;
        }

}
$scaf{$id}=$sequence;   #the last sequence

close(SCAF);

return %scaf;

}

################ End of read_fasta_tohash #################################


############# reverse_complement ################################

sub reverse_complement{
my $ref_str=shift;
my $str = $$ref_str;  # dereferencing the scalar

$str =~ tr/ATGCatgc/TACGtacg/;
my $rev_str= reverse $str;

return $rev_str;
}

##################### End of reverse_complement ####################

                                                              
