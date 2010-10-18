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

Can process fasta files, GFF files, or GFF with embedded fasta.

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

Usage: $0 --input [gff_file] --output [gff_file] --prefix [prefix]
END
;
}

my $out = new IO::File;
$out->open("> $output") or die "Couldn't open the output file: $output $!";

my $in = new IO::File;
if ($in->open($input)) {
    
    my $fasta_seen;

    while (<$in>) {              
        # Comments
        if ($_ =~ /^\#/) {
	    print $out $_ if $_ =~ /^\#\#/;  # Need to retain some comments for splitting fasta
            next;
	    
        # FASTA might be embedded
        } elsif ($fasta_seen || $_ =~ /^>/) {
	    
	    $fasta_seen++;  # We've seen fasta. Start dumping.
	    my ($id) = $_ =~ />(.*)/;
	    if ($id) {
		chomp $id;		
		my $new_id = transmogrify($id);
		print $out ">$new_id\n";
	    } else {
		# Just dump the fasta
		print $out $_;
	    }
	    
	# Plain 'ol annotations.
	} else {
	    process_annotations($_);
	}
    }
}
$in->close;
$out->close;



sub transmogrify {
    my $id = shift;
    
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
    
    # Insert an underscore between the feature
    # type and the feature ID unless this is 
    # something weird like 2-micron. There may be
    # other per-organism cases to deal with later.

    if ($id eq '2-micron') {
	# Totally arbitrary, but let's just call it Chr_
	# for now since it matches downstream regexes.
	$id = 'Chr_2-micron';
    } else {
	$id =~ s/([Chr|contig|supercontig]*)(.*)/$1_$2/;
    }

    # Append the prefix
    my $new_id = "$prefix:$id";
    return $new_id;
}



sub process_annotations {
    my $line = shift;
    
    my ($id,$source,$type,$start,$end,$score,$strand,$phase,$attributes) = split("\t",$line);
    
    # Save the original id for later post-processing.
    my $original_id = $id;
    
    my $new_id = transmogrify($id);
    
    # Fix attributes to match the new id
    $attributes =~ s/$original_id/$new_id/g;
    
    print $out join("\t",$new_id,$source,$type,$start,$end,$score,$strand,$phase,$attributes);
}
