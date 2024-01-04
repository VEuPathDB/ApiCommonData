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

my ($output, $gusConfigFile, $debug, $verbose, $tuningTablePrefix, $downloadsite);

&GetOptions("output=s" => \$output,
            "verbose!" => \$verbose,
            "tuningTablePrefix=s" => \$tuningTablePrefix,
            "gusConfigFile=s" => \$gusConfigFile,
            "downloadsite=s" => \$downloadsite,
	   );

if (!$tuningTablePrefix || !$downloadsite) {
  die ' USAGE: makeNCBILinkoutsFiles_Nucleotide.pl -output <output> -tuningTablePrefix <tuningTablePrefix> -downloadsite <downloadsite>'
}

$downloadsite = lc($downloadsite);

my $contigUrl = "https://${downloadsite}.org/a/app/record/genomic-sequence/";

my $doc = XML::LibXML->load_xml(string => <<"__END_XML__");
<?xml version="1.0"?>
<!DOCTYPE LinkSet PUBLIC "-//NLM//DTD LinkOut 1.0//EN" "https://www.ncbi.nlm.nih.gov/projects/linkout/doc/LinkOut.dtd">
<LinkSet/>
__END_XML__

my $entity_declaration = <<END_ENTITY;
[
  <!ENTITY contig.url "https://${downloadsite}.org/a/app/record/genomic-sequence/">
]
END_ENTITY

# Find the LinkSet node
my ($linkset_node) = $doc->findnodes('//LinkSet');

# Remove existing child nodes
$_->unlink for $linkset_node->childNodes();

# Add the new Entity Declaration as a child node
$linkset_node->appendText($entity_declaration);


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

my $sql = &getNucleotideQuery($tuningTablePrefix);
my $sth = $dbh->prepare($sql) || die "Couldn't prepare the SQL statement: " . $dbh->errstr;
$sth->execute() ||  die "Couldn't execute statement: " . $sth->errstr;

my (%nucleotide, $linkId);

while (my ($source_id) = $sth->fetchrow_array()) {
    $linkId++;
    $nucleotide{$linkId}->{ProviderId} = 5941;
    $nucleotide{$linkId}->{Database} = 'Nucleotide';
    $nucleotide{$linkId}->{Query} = $source_id;
    $nucleotide{$linkId}->{Base} = '&base.url;';
    $nucleotide{$linkId}->{Rule} = '';
}

my $outputIO = IO::File->new(">> ".$output);
my $writer = XML::Writer->new(OUTPUT => $outputIO, DATA_MODE => "true", DATA_INDENT =>2);
$writer->startTag('LinkSet');
    for my $k (sort {$a <=> $b} keys(%nucleotide)){
      $writer->startTag('Link');
      $writer->startTag('LinkId');
      $writer->characters($k);
      $writer->endTag('LinkId');
      $writer->startTag('ProviderId');
      $writer->characters($nucleotide{$k}->{ProviderId});
      $writer->endTag('ProviderId');
      $writer->startTag('ObjectSelector');
      $writer->startTag('Database');
      $writer->characters($nucleotide{$k}->{Database});
      $writer->endTag('Database');
      $writer->startTag('ObjectList');
      $writer->startTag('Query');
      $writer->characters($nucleotide{$k}->{Query});
      $writer->endTag('Query');
      $writer->endTag('ObjectList');
      $writer->endTag('ObjectSelector');
      $writer->startTag('ObjectUrl');
      $writer->startTag('Base');
      $writer->characters($contigUrl);
      #$writer->characters($nucleotide{$k}->{Base});
      $writer->endTag('Base');
      $writer->startTag('Rule');
      $writer->characters($nucleotide{$k}->{Rule});
      $writer->endTag('Rule');
      $writer->endTag('ObjectUrl');
      $writer->endTag('Link');
	}

$writer->endTag('LinkSet');
$writer->end();
$outputIO->close();
$dbh->disconnect;

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

sub getNucleotideQuery {
    my $prefix = shift;
    my $sql = "select SOURCE_ID from ApidbTuning.${prefix}genomicseqattributes where is_top_level =1 ORDER by SOURCE_ID";
    return $sql;
}
