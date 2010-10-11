#!/usr/bin/perl -w

use strict;
use Getopt::Long;
use IO::File;

my ($input,$output,$prefix);
GetOptions('input=s'  => \$input,
	   'output=s' => \$output,
	   'prefix=s' => \$prefix
	   );


die <<END;
Uniquify chromosomes/scaffolds by appending a short prefix
corresponding to the Genus species + strain of the organism
to the original IDs.

eg, for Saccharomyces:
  Chr1 -> Scer_s288c:Chr1

More generally:
   Chromosomes:
   Chr1 -> Scer_s288c:Chr1
   Chromosome1 -> Scer_s288c:Chr1

  Contigs:
  contig1.1  -> contig1.1
  contig_1.1 -> contig1.1
  contig_1   -> contig1

  Supercontigs:
  supercontig_1 -> supercontig1
  supercont_1   -> supercontig1
  scaffold_1    -> scaffold1

Usage: $0 --input [gff_file] --output [gff_file] --prefix [prefix]" unless ($input && $output && $prefix);
END
;


my $out = new IO::File;
$out->open("> $output") or die "Couldn't open the output file: $output $!";

my $in = new IO::File;
if ($in->open("$input) {
    while (<$fh>) {
	my ($ref,@rest) = split("\t");
	
	# Turn Chromosome into Chr
	$ref =~ s/Chromosome/Chr/;

        # Supercontig/contig
        lc($ref) if $ref =~ /contig/i;
        
        # make sure supercontig is spelled out
        $ref =~ s/supercont_/supercontig_/;
       
        # Scaffolds becomes SC; a stajichism.
        $ref =~ s/scaffold/SC/;
	
	# Strip underscores
	$ref =~ s/_//;
	
	# Append the Prefix
	print $out join("\t","$prefix:$ref",@rest);
  }
}
$in->close;
$out->close;
