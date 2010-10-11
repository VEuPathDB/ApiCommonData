#!/usr/bin/perl -w

use strict;
use Getopt::Long;
use IO::File;

my ($input,$output,$prefix);
GetOptions('input=s'  => \$input,
	   'output=s' => \$output,
	   'prefix=s' => \$prefix
	   );

unless ($input && $output && $prefix) {
die <<END;

Uniquify chromosomes/scaffolds by appending a short prefix
corresponding to the Genus species + strain of the organism
to the original IDs.

eg, for Saccharomyces:
  Chr1 -> Scer_s288c:Chr1

More generally:
   Chromosomes:
   Chr1 -> Scer_s288c:Chr_1
   Chromosome1 -> Scer_s288c:Chr_1

  Contigs:
  contig1.1  -> contig1.1
  contig_1.1 -> contig1.1
  contig_1   -> contig1

  Supercontigs:
  supercontig_1 -> supercontig1
  supercont_1   -> supercontig1
  scaffold_1    -> scaffold1

Usage: $0 --input [gff_file] --output [gff_file] --prefix [prefix]"
END
;
}

my $out = new IO::File;
$out->open("> $output") or die "Couldn't open the output file: $output $!";

my $in = new IO::File;
if ($in->open($input)) {
    while (<$in>) {
        next if $_ =~ /^#/;

	my ($id,$source,$type,$start,$end,$score,$strand,$phase,$attributes) = split("\t");
	
        # Save the original id for later post-processing.
        my $original_id = $id;

	# Turn Chromosome into Chr
	$id =~ s/Chromosome/Chr/;

        # Supercontig/contig all lowercase
        $id = lc($id) if $id =~ /contig/i;

        # Chr are ucfirst
        $id = ucfirst($id) if $id =~ /chr/;

        # make sure supercontig is spelled out
        $id =~ s/supercont([_|\d])/supercontig$1/;
       
        # Scaffolds becomes SC; a stajichism.
        $id =~ s/scaffold/SC/;
	
	# Strip underscores
	$id =~ s/_//;

        # Finally, insert an underscore between the feature
        # type and the feature ID.
        $id =~ s/([Chr|contig|supercontig]*)(.*)/$1_$2/;
	
	# Append the prefix
        my $new_id = "$prefix:$id";

        $attributes =~ s/$original_id/$new_id/g;
        
        # Replace the old ref with the new universally.
        print $out join("\t",$new_id,$source,$type,$start,$end,$score,$strand,$phase,$attributes);
  }
}
$in->close;
$out->close;
