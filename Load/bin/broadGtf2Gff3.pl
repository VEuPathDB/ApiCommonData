#!/usr/bin/perl

use strict;
## usage: perl broadGtf2Gff3.pl nematocida_sp1_ertm6_2_transcripts.gtf > nsp1ERTm6_genome.gff3

## a script to convert broad annotation from Gtf format to standard gff3 format

my $input = $ARGV[0];

print "##gff-version 3\n";
print "##date-created at ".localtime()."\n";

my ($currentGeneId, $currentTransId, $preGeneId, $preTransId, $preSeqId, $preSource, $preStrand);
my ($lineCtr, @elems, @attrs, %ctrs, %geneStarts, %geneEnds, %transStarts, %transEnds);

open (IN, $input) || die "can not open input file to read.\n";
while (<IN>) {
    $lineCtr++;
    chomp;

    ## skip the comment line(s)
    next if ($_ =~ /^\#/); 

    ## grep the gene_id and transId for current line
    if($_ =~ /\tgene_id \"(\S+)\"\;.* transcript_id \"(\S+)\"\;/) {
        $currentGeneId = $1;
        $currentTransId = $2;
        $preGeneId = $currentGeneId if (!$preGeneId);
        $preTransId = $currentTransId if (!$preTransId);
    } else {
        die "Can not find either gene_id or transcript_id at the line $lineCtr\n";
    } 
    #print "\$currentGeneId = $currentGeneId\n";

    # print the gene line if reach to new geneID
    if ($currentGeneId ne $preGeneId ) {
        print "$preSeqId\t$preSource\tgene\t$geneStarts{$preGeneId}\t$geneEnds{$preGeneId}\t\.\t$preStrand\t0\t";
        print "ID=$preGeneId\;\n";
    }

    # print the transcript line if reach to new transID
    if ($currentTransId ne $preTransId ) {
        print "$preSeqId\t$preSource\tmRNA\t$transStarts{$preTransId}\t$transEnds{$preTransId}\t\.\t$preStrand\t0\t";
        print "ID=$preTransId\;Parent=$preGeneId\;\n";
    }

    @elems = split (/\t/, $_);

    ## check if gene has been placed by order
    #if ($currentTransId ne $preTransId ) {
    #    if ($elems[2] ne 'start_codon' && $elems[2] ne 'stop_codon' ) {
    #        print STDERR "### WARNING: double check the line $lineCtr, the gene has not been placed by order\n";
    #    } 
    #}

    ## print the majority
    foreach my $i (0..$#elems) {
        if ($i == 8) {          
            @attrs = split (/\;/, $elems[8]);
            foreach my $j (0..$#attrs) {
                $attrs[$j] =~ s/^\s+//;
                $attrs[$j] =~ s/\s+$//;
                if ($attrs[$j]) {
                    my ($tag, $value) = split (/\s/, $attrs[$j]);
                    if ($tag && $value) {
                        $value =~ s/\"//g;
                        if ($tag eq 'gene_id') {
                            $ctrs{$currentTransId}{$elems[2]}++;
                            print "ID\=$currentTransId\:$elems[2]\:$ctrs{$currentTransId}{$elems[2]}\;Parent=$currentTransId\;";
                        }
                        print "$tag\=$value\;";
                    }
                }
            }
        }else{
            print "$elems[$i]\t";   
        }
    }
    print "\n";
    ## end of print the majority
    
    ## collect the coordinate information
    if ($elems[2] eq 'exon') {
	## geneStart and geneEnd
	$geneStarts{$currentGeneId} = ($geneStarts{$currentGeneId}) ? 
	    getMin ($elems[3], $elems[4], $geneStarts{$currentGeneId}) : getMin($elems[3], $elems[4]);
	$geneEnds{$currentGeneId} = ($geneEnds{$currentGeneId}) ? 
	    getMax($elems[3], $elems[4], $geneEnds{$currentGeneId}) : getMax($elems[3], $elems[4]);

	## transcriptStart and transcriptEnd
        if ($transStarts{$currentTransId} ) {
            $transStarts{$currentTransId} = getMin($elems[3], $elems[4], $transStarts{$currentTransId});
        } else {
            $transStarts{$currentTransId} = getMin($elems[3], $elems[4]);
        }
        if ($transEnds{$currentTransId} ) {
            $transEnds{$currentTransId} = getMax($elems[3], $elems[4], $transEnds{$currentTransId});
        } else {
            $transEnds{$currentTransId} = getMax($elems[3], $elems[4]);
        }
    }

    ## reset values before go to next line
    $preGeneId = $currentGeneId;
    $preTransId = $currentTransId;
    $preSeqId = $elems[0];
    $preSource = $elems[1];
    $preStrand = $elems[6];
    $currentGeneId = "";
    $currentTransId = "";
    @elems = ();
    @attrs = ();
}
close IN;

# print the last gene 
        print "$preSeqId\t$preSource\tgene\t$geneStarts{$preGeneId}\t$geneEnds{$preGeneId}\t\.\t$preStrand\t0\t";
        print "ID=$preGeneId\;\n";

# print the last transcript
        print "$preSeqId\t$preSource\tmRNA\t$transStarts{$preTransId}\t$transEnds{$preTransId}\t\.\t$preStrand\t0\t";
        print "ID=$preTransId\;Parent=$preGeneId\;\n";

my $start = getMin (1,2,3,4,5,6,7,8);
my $end = getMax (1,2,3,4,5,6,7,8,9);
print STDERR "start = $start\tend = $end\n";

##################

sub getMax {
    my @array = @_;
    
    my @sortedArray = sort {$a <=> $b} @array;
    return $sortedArray[-1];
}

sub getMin {
    my @array = @_;
    my @sortedArray = sort {$a <=> $b} @array;
    return $sortedArray[0];
}

