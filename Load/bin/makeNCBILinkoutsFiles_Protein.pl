#!/usr/bin/perl
## To make the xml files for NCBI linkouts

use strict;
use DBI;
use lib "$ENV{GUS_HOME}/lib/perl";
use CBIL::Util::PropertySet;
use Getopt::Long;
use XML::Writer;
use IO::File;
use HTML::Entities;
use XML::LibXML;

my ($output, $gusConfigFile, $debug, $verbose, $organismAbbrev);

&GetOptions("output=s" => \$output,
            "verbose!" => \$verbose,
            "organismAbbrev=s" => \$organismAbbrev,
            "gusConfigFile=s" => \$gusConfigFile,
	   );

if (!$output || !$organismAbbrev) {
  die ' USAGE: makeNCBILinkoutsFiles.pl -output <output> -organismAbbrev <organismAbbrev>'
}

my $doc = XML::LibXML->load_xml(string => <<__END_XML__);
<?xml version="1.0"?>
<!DOCTYPE LinkSet PUBLIC "-//NLM//DTD LinkOut 1.0//EN" 
"https://www.ncbi.nlm.nih.gov/projects/linkout/doc/LinkOut.dtd" 
[
  <!ENTITY contig.url "http://cryptodb.org/cryptodb/showRecord.do?name=ContigRecordClasses.ContigRecordClass&amp;id=">
  <!ENTITY gene.url "http://cryptodb.org/cryptodb/showRecord.do?name=GeneRecordClasses.GeneRecordClass&amp;id=">
]
><LinkSet/>
__END_XML__


open(OUT, "> $output") or die "Cannot open $output for writing: $!";

$doc =~ s/<LinkSet\/>//g;
print OUT "$doc";

close OUT;

$gusConfigFile = $ENV{GUS_HOME} . "/config/gus.config" unless($gusConfigFile);

unless(-e $gusConfigFile) {
  print STDERR "gus.config file not found! \n";
  exit;
}

my @properties = ();
my $gusconfig = CBIL::Util::PropertySet->new($gusConfigFile, \@properties, 1);

my $usr = $gusconfig->{props}->{databaseLogin};
my $pwd = $gusconfig->{props}->{databasePassword};
my $dsn = $gusconfig->{props}->{dbiDsn};

print "Establishing dbi login\n" if $verbose;
my $dbh = DBI->connect($dsn, $usr, $pwd) ||  die "Couldn't connect to database: " . DBI->errstr;
$dbh->{RaiseError} = 1;
$dbh->{AutoCommit} = 0;

my $sql = &getProteinQuery($organismAbbrev);
my $sth = $dbh->prepare($sql) || die "Couldn't prepare the SQL statement: " . $dbh->errstr;
$sth->execute() ||  die "Couldn't execute statement: " . $sth->errstr;

my (%protein, $linkId);

while (my ($source_id, $primary_identifier) = $sth->fetchrow_array()) {
    $linkId++;
    $protein{$linkId}->{ProviderId} = 5941;
    $protein{$linkId}->{Database} = 'Protein';
    $protein{$linkId}->{ObjId} = $primary_identifier;
    $protein{$linkId}->{Base} = '&gene.url;';
    $protein{$linkId}->{Rule} = $source_id;
    $protein{$linkId}->{SubjectType} = 'DNA/protein sequence';

}

my $outputIO = IO::File->new(">> ".$output);
my $writer = XML::Writer->new(OUTPUT => $outputIO, DATA_MODE => "true", DATA_INDENT =>2);
$writer->startTag('LinkSet');
    for my $k (sort {$a <=> $b} keys(%protein)){
      $writer->startTag('Link');
      $writer->startTag('LinkId');
      $writer->characters($k);
      $writer->endTag('LinkId');
      $writer->startTag('ProviderId');
      $writer->characters($protein{$k}->{ProviderId});
      $writer->endTag('ProviderId');
      $writer->startTag('ObjectSelector');
      $writer->startTag('Database');
      $writer->characters($protein{$k}->{Database});
      $writer->endTag('Database');
      $writer->startTag('ObjectList');
      $writer->startTag('ObjId');
      $writer->characters($protein{$k}->{ObjId});
      $writer->endTag('ObjId');
      $writer->endTag('ObjectList');
      $writer->endTag('ObjectSelector');
      $writer->startTag('ObjectUrl');
      $writer->startTag('Base');
      $writer->characters($protein{$k}->{Base});
      $writer->endTag('Base');
      $writer->startTag('Rule');
      $writer->characters($protein{$k}->{Rule});
      $writer->endTag('Rule');
      $writer->startTag('SubjectType');
      $writer->characters($protein{$k}->{SubjectType});
      $writer->endTag('SubjectType');
      $writer->endTag('ObjectUrl');
      $writer->endTag('Link');
	}

$writer->endTag('LinkSet');
$writer->end();
$outputIO->close();
$dbh->disconnect;

if ($linkId){
	rename($output, $output . '.bak');
	open(IN, '<' . $output . '.bak') or die $!;
	open(OUT, '>' . $output) or die $!;
	while(<IN>)
	{
    	$_ =~ s/&amp;/&/g;
    	print OUT $_;
	}	
	close(IN);
	close(OUT);
	unlink($output . '.bak'); 
}else {
	unlink($output);
}
sub getProteinQuery {
    my $org_Abbrev = shift;
    my $sql = "
select nf.SOURCE_ID, d.PRIMARY_IDENTIFIER from DOTS.NAFEATURE nf
 , DOTS.DBREFNAFEATURE dnf
 , SRES.DBREF d
 , SRES.EXTERNALDATABASE ed
 , SRES.EXTERNALDATABASERELEASE edr
where nf.NA_FEATURE_ID=dnf.NA_FEATURE_ID
 and dnf.DB_REF_ID=d.DB_REF_ID
 and d.EXTERNAL_DATABASE_RELEASE_ID=edr.EXTERNAL_DATABASE_RELEASE_ID
 and edr.EXTERNAL_DATABASE_ID=ed.EXTERNAL_DATABASE_ID
 and ed.NAME like '${org_Abbrev}_dbxref_gene2Entrez_RSRC'
";
    return $sql;
}
