package binduGetData;

use HTTP::Request::Common;
use LWP::UserAgent;
use Net::FTP;

use strict;

sub usage {
    die "USAGE: perl getPubChemData.pl (-id <id> | -file <file>)";
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

print "Using $inputType, $id, $fileName\n";

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
