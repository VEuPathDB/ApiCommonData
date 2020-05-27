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

print "    <summary><![CDATA[$plainText for ";
&printOrganismFullName($organismFullName) if ($organismFullName);
print "\n                  ]]></summary>\n";

print "    <description><![CDATA[\n";
print "\n                  ]]><\/description>\n";

print "    <protocol><\/protocol>\n";
print "    <caveat><\/caveat>\n";
print "    <acknowledgement><\/acknowledgement>\n";
print "    <releasePolicy><\/releasePolicy>\n";
&printHistory($buildNumber);
print "    <primaryContactId><\/primaryContactId>\n";

&printExternalLinks();
print "    <pubmedId></pubmedId>\n";

($isAnnotatedGenome =~ /^y/i) ? &printAnnotatedGenome : &printUnAnnotatedGenome;

print "  </datasetPresenter>\n";


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

sub printUnAnnotatedGenome {
  my ($temp) = @_;

  print "    <templateInjector className=\"org.apidb.apicommon.model.datasetInjector.UnannotatedGenome\"\/>\n";
  return 0;
}

sub printHistory {
  my ($bld, $source, $version) = @_;

  print "    <history buildNumber=\"$bld\"\n";
  print "             genomeSource=\"$source\" genomeVersion=\"$version\"\n";
  print "             annotationSource=\"$source\" annotationVersion=\"$version\"\/>\n";
  return 0;
}

sub printExternalLinks {
  my ($temp) = @_;

  print "    <link>\n";
  print "      <text>NCBI Bioproject<\/text>\n";
  print "      <url><\/url>\n";
  print "    </link>\n";
  print "    <link>\n";
  print "      <text>GenBank Assembly page<\/text>\n";
  print "      <url></url>\n";
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

";
}
