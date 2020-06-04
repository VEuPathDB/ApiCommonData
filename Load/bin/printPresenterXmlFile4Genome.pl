#!/usr/bin/perl

use Getopt::Long;
use strict;
use lib "$ENV{GUS_HOME}/lib/perl";

use DBI;
use DBD::Oracle;
use CBIL::Util::PropertySet;

my (
    $projectName,
    $organismAbbrev,
    $organismFullName,
    $isAnnotatedGenome,
    $buildNumber,
    $genomeSource,
    $genomeVersion,
    $pubMedId,
    $primaryContactId,
    $assemblyId,
    $bioprojectId,
    $ifPrintContactIdFile,
    $help);

&GetOptions(
	    'projectName=s' => \$projectName,
	    'organismAbbrev=s' => \$organismAbbrev,
            'organismFullName=s' => \$organismFullName,
	    'isAnnotatedGenome=s' => \$isAnnotatedGenome,
	    'buildNumber=s' => \$buildNumber,
	    'genomeSource=s' => \$genomeSource,
	    'genomeVersion=s' => \$genomeVersion,
	    'pubMedId=s' => \$pubMedId,
	    'primaryContactId=s' => \$primaryContactId,
	    'assemblyId=s' => \$assemblyId,
	    'bioprojectId=s' => \$bioprojectId,
	    'ifPrintContactIdFile=s' => \$ifPrintContactIdFile,
	    'help|h' => \$help,
	    );
&usage() if($help);
&usage("Missing a Required Argument") unless(defined $projectName && $organismAbbrev);


## printPresentTemplate
my $plainText = ($isAnnotatedGenome =~ /^y/i) ? "Genome Sequence and Annotation" : "Genome Sequence";

print "  <datasetPresenter name=\"$organismAbbrev\_primary_genome_RSRC\"\n";
print "                    projectName=\"$projectName\">\n";

print "    <displayName><![CDATA[$plainText]]></displayName>\n";  ## need change by $isAnnot
print "    <shortDisplayName></shortDisplayName>\n";
print "    <shortAttribution></shortAttribution>\n";
&printSummary();
&printDescription();

print "    <protocol><\/protocol>\n";
print "    <caveat><\/caveat>\n";
print "    <acknowledgement><\/acknowledgement>\n";
print "    <releasePolicy><\/releasePolicy>\n";

&printHistory();
&printPrimaryContactId();
&printExternalLinks();
&printPubMedId();

($isAnnotatedGenome =~ /^y/i) ? &printAnnotatedGenome : &printUnAnnotatedGenome;

print "  </datasetPresenter>\n";

print printContactInformation($primaryContactId) if ($ifPrintContactIdFile =~ /^y/i);

##################### subroutine ###################
sub printAnnotatedGenome {
  my ($temp) = @_;

  print "    <templateInjector className=\"org.apidb.apicommon.model.datasetInjector.AnnotatedGenome\">\n";

  print "      <prop name=\"isEuPathDBSite\">true<\/prop>\n";
  print "      <prop name=\"optionalSpecies\"><\/prop>\n";
  print "      <prop name=\"specialLinkDisplayText\"><\/prop>\n";
  print "      <prop name=\"updatedAnnotationText\"><\/prop>\n";
  print "      <prop name=\"isCurated\">false<\/prop>\n";
  print "      <prop name=\"specialLinkExternalDbName\"><\/prop>\n";
  print "      <prop name=\"showReferenceTranscriptomics\">false<\/prop>\n";
  print "    <\/templateInjector>\n";

  return 0;
}

sub printSummary {
  my ($id) = @_;
  print "    <summary><![CDATA[$plainText for ";
  &printOrganismFullName($organismFullName) if ($organismFullName);
  print "\n                  ]]></summary>\n";
  return 0;
}

sub printDescription {
  my ($id) = @_;
  print "    <description><![CDATA[\n";
  print "                    $plainText for ";
  &printOrganismFullName($organismFullName) if ($organismFullName);
  print "\n\n                  ]]><\/description>\n";
}

sub printPubMedId {
  my ($id) = @_;
  print "    <pubmedId>$pubMedId</pubmedId>\n";
  return 0;
}

sub printPrimaryContactId {

  my $name = optimizedContactId ($primaryContactId);

  ($primaryContactId) ? print "    <primaryContactId>$name<\/primaryContactId>\n"
                      : print "    <primaryContactId>TODO<\/primaryContactId>\n";
  return 0;
}

sub optimizedContactId {
  my ($name) = @_;

  $name = lc ($name);
  $name =~ s/^\s+//;
  $name =~ s/\s+$//;
  $name =~ s/\s+/\./g;

  return $name;
}

sub printUnAnnotatedGenome {
  my ($temp) = @_;

  print "    <templateInjector className=\"org.apidb.apicommon.model.datasetInjector.UnannotatedGenome\"\/>\n";
  return 0;
}

sub printHistory {
  my ($bld, $source, $version) = @_;

  print "    <history buildNumber=\"$buildNumber\"\n";
  ($genomeSource eq "INSDC" || $genomeSource =~ /genbank/i) ? print "             genomeSource=\"$genomeSource\" genomeVersion=\"$assemblyId\"\n"
                                                            : print "             genomeSource=\"$genomeSource\" genomeVersion=\"$genomeVersion\"\n";
  print "             annotationSource=\"\" annotationVersion=\"\"\/>\n";
  return 0;
}

sub printExternalLinks {
  my ($temp) = @_;

  print "    <link>\n";
  print "      <text>NCBI Bioproject<\/text>\n";
  ($bioprojectId) ? print "      <url>https:\/\/www.ncbi.nlm.nih.gov\/bioproject\/$bioprojectId<\/url>\n" : print "      <url><\/url>\n";
  print "    </link>\n";
  print "    <link>\n";
  print "      <text>GenBank Assembly page<\/text>\n";
  ($assemblyId) ? print "      <url>https:\/\/www.ncbi.nlm.nih.gov\/assembly\/$assemblyId</url>\n" : print "      <url></url>\n";
  print "    </link>\n";

  return 0;
}

sub printOrganismFullName {
  my ($fullName) = @_;

  my @items = split (/\s/, $fullName);
  my $genus = shift @items;
  my $species = shift @items;
  my $strain = join (" ", @items);

  print "<i>$genus $species</i> $strain";

  return 0;
}
sub printContactInformation {
  my ($fullName) = @_;
  my $id = optimizedContactId ($fullName);

  print "\n\n\n";
  print "  <contact>\n";
  print "    <contactId>$id<\/contactId>\n";
  print "    <name>$fullName<\/name>\n";
  print "    <institution><\/institution>\n";
  print "    <email><\/email>\n";
  print "    <address\/>\n";
  print "    <city\/>\n";
  print "    <state\/>\n";
  print "    <zip\/>\n";
  print "    <country\/>\n";
  print "  <\/contact>\n";

  return 0;
}


sub usage {
  die
"
Usage: printPresenterXmlFile4Genome.pl --organismAbbrev tgonME49 --projectName ToxoDB --isAnnotatedGenome Y
                                       --organismFullName \"Toxoplasma gondii ME49\" --buildNumber 49

where
  --organismAbbrev: required, the organism abbrev
  --projectName: required, project name, such as PlasmoDB, etc. in full name
  --isAnnotatedGenome: required, Yes|yes|Y|y, No|no|N|n
  --organismFullName: optional
  --buildNumber: optional
  --genomeSource: optional
  --genomeVersion: optional, e.g. Mar 21, 2015
  --pubMedId: optional
  --primaryContactId: optional
  --assemblyId: optional
  --bioprojectId: optional
  --ifPrintContactIdFile: optional, Yes|yes|Y|y, No|no|N|n

";
}
