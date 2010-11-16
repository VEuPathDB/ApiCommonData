#!/usr/bin/perl -w

use strict;
use Getopt::Long;
use IO::File;

my ($input,$output,$prefix,$ignore_features,$ignore_contigs);
GetOptions('input=s'    => \$input,
	   'output=s'   => \$output,
	   'prefix=s'   => \$prefix,
	   'ignore_feature' => \$ignore_features,
	   'ignore_contigs' => \$ignore_contigs,
	   );

unless ($input && $output && $prefix) {
die <<END;

Uniquify chromosomes/scaffolds and gene IDs by appending a short prefix
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

You can use the --ignore_* to limit which types of IDs are modified. Some may already be unique.

  --ignore_contigs   // leave contig IDs alone
  --ignore_features  // leave feature IDs alone

By default, both contig (reference sequence) IDs and feature IDs (in the ninth column) will be updated.

Usage: $0 --input [gff_file] --output [gff_file] --prefix [prefix] [--ignore_features] [--ignore_contigs]
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
	chomp;    
        if ($_ =~ /^\#/) {
	    print $out "$_\n" if $_ =~ /^\#\#/;  # Need to retain some comments for splitting fasta
            next;
	    
        # FASTA might be embedded
        } elsif ($fasta_seen || $_ =~ /^>/) {
	    
	    $fasta_seen++;  # We've seen fasta. Start dumping.
	    my ($id) = $_ =~ />(.*)/;
	    if ($id) {
		chomp $id;		
		my $new_id = ($ignore_contigs) ? $id : transmogrify($id);
		print $out ">$new_id\n";
	    } else {
		# Just dump the fasta
		print $out "$_\n";
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

    my $new_id;
    # Don't bother fixing the reference sequence ID if --ignore_sequences
    if ($ignore_contigs) {
	$new_id = $id;
    } else {
	$new_id = transmogrify($id);
	
	# Fix the ID in attributes, too
	$attributes =~ s/$id/$new_id/g;
    } 


    # Don't bother updating attributes for sequence features if --ignore_sequences
    if (($type =~ /chr|chromosome|supercontig|contig/) && $ignore_contigs) {
	# $new_id = $original_id;
    } else {
	unless ($ignore_features) {
	    my @attributes = split(";",$attributes);	
	    my @new_attributes;
	    foreach (@attributes) {
		my ($key,$value) = split('=');
		if ($key eq 'Parent'
		    ||
		    $key eq 'ID'
		    ||
		    $key eq 'Name') {
		    push @new_attributes,"$key=$prefix:$value";
		    push (@new_attributes,"Alias=" . $value) if ($key eq 'ID' || $key eq 'Name');
		} else {
		    push @new_attributes,"$key=$value";
		}
	    }
	    $attributes = join(';',@new_attributes);
	}
    }
    print $out join("\t",$new_id,$source,$type,$start,$end,$score,$strand,$phase,$attributes) . "\n";
}
