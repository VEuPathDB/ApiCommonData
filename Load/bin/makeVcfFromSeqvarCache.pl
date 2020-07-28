#!/usr/bin/perl
use strict;

use lib "$ENV{GUS_HOME}/lib/perl"; 
use Data::Dumper;

use ApiCommonData::Load::VariationFileReader;



my $organismDir = "/eupath/data/EuPathDB/workflows/PlasmoDB/26/data/pfal3D7";
my $coverageFilesDir = $organismDir."/SNPs_HTS/varscanCons";
my $fastaFile = $organismDir."/loadGenome/genomicSeqs.fa";
my @coverageFiles = glob "$coverageFilesDir/*.coverage.txt";
my $refStrain = "3D7";
my @allStrains = map { /$coverageFilesDir\/(.+)\.coverage.txt/; $1 } @coverageFiles;

my @orderedStrains = ();
foreach (@allStrains) {
    if ($_ ne $refStrain) {
	push @orderedStrains, $_;
    }
}

open(vcfFH, '>', 'output.vcf') or die "Unable to write to VCF file.\n";

my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime();
$year += 1900;
$mon += 1;

print vcfFH "##fileformat=VCFv4.2\n";
print vcfFH "##fileDate=";
printf vcfFH ("%04d%02d%02d\n", $year, $mon, $mday);
print vcfFH "##source=varscan\n";
print vcfFH "##reference=$fastaFile\n";

open(fastaFH, "$fastaFile") or die "Unable to open FASTA file.\n";
while (<fastaFH>) {
    if (/>(\w+)\s+length=(\d+)/) {
	my ($id,$length)=($1,$2);
	print vcfFH "##contig=<ID=$id,length=$length>\n";
    }
}
close fastaFH;

print vcfFH "##phasing=no\n";
print vcfFH "##INFO=<ID=RA,Number=1,Type=String,Description=\"reference_amino_acid\">\n";

my %format = (
    CV => {
	Number => "R",
	Type => "Integer",
	Description => "coverage",
	Hash_name => "coverage",
    },
    RP => {
	Number => "R",
	Type => "Float",
	Description => "read_percentage",
        Hash_name => "percent",
    },
    PP => {
	Number => "1",
	Type => "Integer",
	Description => "position_in_protein",
        Hash_name => "position_in_protein",
    },
    PS => {
	Number => "1",
	Type => "Integer",
	Description => "positions_in_protein",
        Hash_name => "positions_in_protein",
    },
    PC => {
	Number => "1",
	Type => "Integer",
	Description => "positions_in_cds",
        Hash_name => "positions_in_cds",
    },
    PA => {
	Number => "1",
	Type => "Integer",
	Description => "protocol_app_node_id",
        Hash_name => "protocol_app_node_id",
    },
    RN => {
	Number => "1",
	Type => "Integer",
	Description => "ref_na_sequence_id",
        Hash_name => "ref_na_sequence_id",
    },
    PV => {
	Number => "R",
	Type => "Float",
	Description => "pvalue",
        Hash_name => "pvalue",
    },
    QL => {
	Number => "R",
	Type => "Integer",
	Description => "quality",
        Hash_name => "quality",
    },
    PR => {
	Number => "R",
	Type => "String",
	Description => "product",
        Hash_name => "product",
    },
    PO => {
	Number => "R",
	Type => "String",
	Description => "products",
        Hash_name => "products",
    },
    DA => {
	Number => "R",
	Type => "Integer",
	Description => "Different_product_due_to_adjacent_SNP",
        Hash_name => "diff_from_adjacent",
    },
    EX => {
	Number => "1",
	Type => "Integer",
	Description => "external_database_release_id",
        Hash_name => "external_database_release_id",
    },
    SE => {
	Number => "1",
	Type => "Integer",
	Description => "snp_external_database_release_id",
        Hash_name => "snp_external_database_release_id",
    },
    NA => {
	Number => "1",
	Type => "Integer",
	Description => "na_sequence_id",
        Hash_name => "na_sequence_id",
    },
);

my @formatOrder = qw( RP CV QL PR DA PP PS PC PV );

foreach my $current (@formatOrder) {
    print vcfFH "##FORMAT=<ID=$current,";
    print vcfFH "Number=$format{$current}{Number},";
    print vcfFH "Type=$format{$current}{Type},";
    print vcfFH "Description=\"$format{$current}{Description}\">\n";
}

my @header = qw( #CHROM POS ID REF ALT QUAL FILTER INFO FORMAT );
@header = (@header, @orderedStrains);
print vcfFH join("\t",@header)."\n";

my $readFreqCutoff = 0;
my $inputVariantsFile = "/eupath/data/EuPathDB/workflows/PlasmoDB/26/data/pfal3D7/SNPs_HTS/SeqvarCache.dat";
my @filters = ($readFreqCutoff);
my $reader = ApiCommonData::Load::VariationFileReader->new($inputVariantsFile, \@filters, qr/\t/);

#my $count = 0;

while($reader->hasNext()) {

  my $variations = $reader->nextSNP();

  my @line = variationToVcf($variations,\@orderedStrains,$refStrain,\@formatOrder,\%format);
  print vcfFH join("\t",@line)."\n";

  #last if $count==10;
  #$count++;

#  my @strainAlleles = map { $_->{strain} . ":" . $_->{base} } @$variations;
#  print "VARIATIONS_EXAMPLE=" . join(" ", @strainAlleles) . "\n";


}

close vcfFH;


exit;







sub variationToVcf {
   my ($variations,$strainsRef,$refStrain,$formatOrderRef,$formatHashRef) = @_;

   # my %pointer;
   # my $i=9;
   # foreach (@orderedStrains) {
   #     $pointer{$_} = $i;
   #     $i++;
   # }
   my %formatHash = %$formatHashRef;
   my %varHash = {};
   my $seq_source_id = ".";
   my $location = ".";
   my $snp_source_id = ".";
   my $refAllele = ".";
   my @altAlleles = ();
   my $quality = ".";
   my $filter = ".";
   my $info = "RA=";

   foreach my $variation (@$variations) {
        if ($variation->{strain} eq $refStrain) {
	   $seq_source_id = getOrReplace($variation->{sequence_source_id},".");
	   $location = getOrReplace($variation->{location},-1);
	   $snp_source_id = getOrReplace($variation->{snp_source_id},".");
	   $refAllele = getOrReplace($variation->{base},".");
	   $info = $info.getOrReplace($variation->{product},".");
       }
       while ( my ($k,$v) = each %$variation ) {
	   $v = getOrReplace($v,"");
	   if (exists ${$varHash{$variation->{strain}}{$k}}[0]) {
	       push @{$varHash{$variation->{strain}}{$k}}, $v;
	   } else {
	       $varHash{$variation->{strain}}{$k} = [$v];
	   }

	   if ($variation->{matches_reference} == 0) {
	       if (! grep(/^$variation->{base}$/,@altAlleles)) {
		   push @altAlleles, getOrReplace($variation->{base},".");
	       }
    	   }

       }
       
   }
   
   my @line = ($seq_source_id,$location,$snp_source_id,$refAllele,join(",",@altAlleles),$quality,$filter,$info,join(":",@$formatOrderRef));

   my %alleleOrder = {};
   my $totalAlleles = 1 + scalar @altAlleles;
   $alleleOrder{$refAllele}=0;
   for (my $i=1; $i < $totalAlleles; $i++) {
       $alleleOrder{$altAlleles[$i-1]}=$i;
   }

   foreach my $strain (@$strainsRef) {

       my @strainFormat = ();

       my %pos = {};
       
       if (exists $varHash{$strain}->{base}[0]) {
	   my $numStrainAlleles = scalar @{$varHash{$strain}->{base}};
       
	   for (my $i=0; $i < $numStrainAlleles ; $i++) {
	       $pos{$alleleOrder{$varHash{$strain}->{base}[$i]}} = $i;
	   }
       }
 
       foreach my $formatItem (@$formatOrderRef) {
	   my $text;
	   my $replace = ".";
	   if ($formatHash{$formatItem}->{Type} eq "Integer" || $formatHash{$formatItem}->{Type} eq "Float") {
	       $replace = -1;
	   }
	   my @pieces = ();
	   if ($formatHash{$formatItem}->{Number} eq "R") {
	       for (my $i=0; $i < $totalAlleles; $i++) {
		   if (exists $pos{$i} ) {
		       $pieces[$i] = getOrReplace($varHash{$strain}->{$formatHash{$formatItem}->{Hash_name}}[$pos{$i}],$replace);
		   } else {
		       $pieces[$i] = $replace;
		   }
		   
		   if ($pieces[$i] eq "") {
		       print "$i $pos{$i} $formatHash{$formatItem}->{Hash_name}\n";
		       exit;
		   }


	       }
	       $text = join(",",@pieces);
	   } else {
	       $text = getOrReplace(${varHash{$strain}->{$formatHash{$formatItem}->{Hash_name}}}[0],$replace);
	   }

	   push @strainFormat, $text;
       }

       push @line, join(":",@strainFormat);
       
   }

   return @line;
}
1;




sub getOrReplace {
    my ($value,$replace) = @_;
    if (defined $value and length $value ) {
	return $value;
    } else {
	return $replace;
    }
}
1;
