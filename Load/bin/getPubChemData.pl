#!/usr/bin/perl
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

package getPubChemData;

use HTTP::Request::Common;
use LWP::UserAgent;
use Net::FTP;

use strict;

sub usage {
    print STDERR "\nRetrieves XML-formatted PubChem data from NCBI based on an ID or file of IDs\n\n";
    print STDERR "   USAGE: getPubChemData.pl (-id <id> | -file <file>)\n\n";
    exit;
}

if ($#ARGV != 1) { usage; }

my ($inputType, $id, $fileName);

if ($ARGV[0] eq "-id") {
    ($inputType, $id, $fileName) = ("fromstring", $ARGV[1], "");
}
elsif ($ARGV[0] eq "-file") {
    ($inputType, $id, $fileName) = ("fromfile", "", $ARGV[1]);
}
else {
    usage;
}

my $req = POST 'http://pubchem.ncbi.nlm.nih.gov/pc_fetch/pc_fetch.cgi',
          'Content-Type' => 'multipart/form-data',
          'Content' => [ retmode => "xml",
                         n_conf => "1",
                         db => "pccompound",
                         idinput => "$inputType",
                         idstr => "$id",
                         idfile => ["$fileName"],
                         compression => "none"];

my $ua = LWP::UserAgent->new;
my $response = $ua->request($req);

if ($response->is_success) {
    my $content = $response->content;
    my $host; my $file;
    if ($content =~ /ftp:\/\/([a-zA-Z0-9\.\-]*)\/(.*\.xml)/) {
	($host, $file) = ($1, $2);
        my $ftp = Net::FTP->new($host, Debug => 0) or die "Cannot connect to $host: $@";
	$ftp->login('anonymous','');
	$ftp->ascii();
        my $fileName = $ftp->get($file);
        open(FILE, $fileName) or die "Can't open downloaded file $fileName\n";
	while (<FILE>) {
	    print;
	}
	close(FILE);
        unlink($fileName);
        #print "Will try to get $file from $host\n";
    }
    else {
        print $content;
        die "Unable to find download link in response.\n";
    }
}
else {
    die $response->status_line;
}
