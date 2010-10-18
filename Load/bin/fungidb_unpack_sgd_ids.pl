#!/usr/bin/perl -w

use strict;
use Getopt::Long;
use IO::File;

my ($input,$output,$db,$type);
GetOptions('input=s'  => \$input,
	   'output=s' => \$output,
	   'db=s'     => \$db,
	   'type=s'   => \$type,
	   );

unless ($input && $output && $db && $type) {
die <<END;

Unpack external IDs from SGD's dbxref.tab file.

  http://downloads.yeastgenome.org/chromosomal_feature/

Usage: $0 --input [gff_file] --output [gff_file] --db [db] --type [type]

   eg --input dbxref.tab --output ec_ids.tab --db IUMBB --type EC number

Output format:
 SGD_source_id \t ID

END
;
}

my $out = new IO::File;
$out->open("> $output") or die "Couldn't open the output file: $output $!";

my $in = new IO::File;
if ($in->open($input)) {
    
    while (<$in>) {              
        # Comments
        next if ($_ =~ /^\#/);
	my @fields = split("\t");
	if (($fields[1] eq $db) && ($fields[2] eq $type))  {
	    print $out "$fields[3]\t$fields[0]\n";
        }
     }
}
$in->close;
$out->close;

