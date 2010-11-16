#!/usr/bin/perl -w

use strict;
use Getopt::Long;
use IO::File;

my ($input,$output,$prefix,$col);
GetOptions('input=s'  => \$input,
	   'output=s' => \$output,
           'prefix=s' => \$prefix,
           'col=s'    => \$col,
	   );

unless ($input && $output && $col && $prefix) {
die <<END;

Prepend FungiDB ID used for uniquifying gene IDs.

Usage: $0 --input [gff_file] --output [gff_file] --prefix [PREFIX] --col [col]

   eg --input go_terms.tab --output go_terms.uniqifuied.tab --prefix ScerS288C --col 0

Where --col is zero-based index of the column to prepend.

END
;
}

my $out = new IO::File;
$out->open("> $output") or die "Couldn't open the output file: $output $!";

my $in = new IO::File;
if ($in->open($input)) {
    
    while (<$in>) {              
	chomp;
        # Comments
        next if ($_ =~ /^\#/);
	my @fields = split("\t");

	my $prepend_field = $fields[$col];
	$fields[$col] = "$prefix:$prepend_field";
	print $out join("\t",@fields) . "\n";
     }
}
$in->close;
$out->close;

