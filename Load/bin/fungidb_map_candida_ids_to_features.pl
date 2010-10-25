#!/usr/bin/perl -w

use strict;

use Getopt::Long;
use IO::File;

my ($input,$output,$prefix,$id_to_dbxref);
GetOptions('input=s'    => \$input,
	   'output=s'   => \$output,
	   'prefix=s'   => \$prefix,
	   'id_to_dbxref=s' => \$id_to_dbxref,
	   );

unless ($input && $output && $prefix) {
die <<END;

Candida doesn't use their CGDIDs in their GFF files.  Let's map our uniqufied geneIDs (Calb_sc5314:...) to CGDIDs.

In doing so, we'll also create a number of other mappings to be loaded as aliases:

  unique_gene_id => alias(es)
  unique_gene_id => internal CGDID

If the optional --id_to_dbxref is provided, that file will be used to secondarily map our unique IDs
to secondary xrefs via the internal CGDID.

Usage: $0 --input [annotation_file] --output [tabbed file] --prefix [prefix] [--id_to_dbxref file]
END
;
}


=pod

0.  Feature name (mandatory); this is the primary orf19 name, if available
1.  Gene name (locus name)
2.  Aliases (multiples separated by |)
3.  Feature type
4.  Chromosome
5.  Start Coordinate
6.  Stop Coordinate
7.  Strand 
8.  Primary CGDID
9. Secondary CGDID (if any)
10. Description
11. Date Created
12. Sequence Coordinate Version Date (if any)
13. Blank
14. Blank
15. Date of gene name reservation (if any).
16. Has the reserved gene name become the standard name? (Y/N)
17. Name of S. cerevisiae ortholog(s) (multiples separated by |)

=cut



my $out = new IO::File;
$out->open("> $output") or die "Couldn't open the output file: $output $!";

# Create a mapping of the internal unique IDs to external dbxrefs
if ($id_to_dbxref) {
  my $in = new IO::File;
  my %genes;
  if ($in->open($id_to_db_xref) {
     while (<$in>) {
        chomp;
        my ($id,$xref) = split("\t");
        $id   =~ /CGD://;         # Strip some junk
        $xref =~ /UniProtKB://;   # Why do people do this to me?
        $genes{$id} = $xref;
  }

  close $in;
}


my $in = new IO::File;
if ($in->open($input)) {
    
    my $fasta_seen;

    while (<$in>) {
      my @values = split("\t");

      my $unique  = "$prefix:$values[0]";

      my @aliases = split("|",$values[2]);
      push @aliases, $values[8];                       # CGD primary ID
      push @aliases, $values[9] if $values[9] ne '';   # CGD secondary ID, if it exists


      # associate our unique IDs with xrefs via the CGDID. Annoying.
      if ($id_to_dbxref) {
         my $xref = $genes{$values[8]};
         if ($xref) {
             print $out "$unique\t$xref\n";
         }
     } else {
    
        # We're just parsing the annotation file iteself for aliases.
        foreach (@aliases) {
                print $out "$unique\t$_\n";
         }
     }
}
