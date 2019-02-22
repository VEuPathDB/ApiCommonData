#!/usr/bin/perl

use strict;
use warnings;
use Cwd;
use HTML::TreeBuilder;
use Data::Dumper;

my ($dataSourceName, $displayName, $shortDisplayName, $shortAttribution, $datasetSummary, $datasetDescription, $contact)=('TODO') x 7;

my $usage =<<EOL;
Automate the creation of presenter entries from the redmine descriptions. Output will be dataset presenter xml
MUST run this script under manual delivery workSpace directory! e.g /eupath/data/EuPathDB/manualDelivery/TriTrypDB/tbruTREU927/SNP/Weir_Population_Genomics/2013-05-21/workSpace
%>createPresenterFromRedmineDesc.pl file_with_redmine_descriptions.html

EOL

my $file = shift or die $usage;
my $buildNumber = shift or die $usage;
my @dir = split /\//, getcwd;
my $project = $dir[5];
my $org     = $dir[6];
my $dataType     = $dir[7];
my $exp     = $dir[8];
my $version = $dir[9];

$dataSourceName = $org.'_'.$exp.'_'.$dataType.'_RSRC';

my $p=HTML::TreeBuilder->new_from_file("$file");

my @urls=$p->find('_tag'=>'li');
foreach (@urls){
 if ($_->as_text=~/Display name/){
     my @vals = split /:/, $_->as_text;
     $displayName = $vals[1];
 }elsif ($_->as_text=~/Short display name/){
	my @vals = split /:/, $_->as_text;
    $shortDisplayName = $vals[1];
 }elsif ($_->as_text=~/Short Attribution/){
    my @vals = split /:/, $_->as_text;
    $shortAttribution = $vals[1];
 }elsif ($_->as_text=~/Dataset Summary/){
    my @vals = split /:/, $_->as_text;
    $datasetSummary = $vals[1];
 }elsif ($_->as_text=~/Dataset Description/){
    my @vals = split /:/, $_->as_text;
    $datasetDescription = $vals[1];
 }elsif ($_->as_text=~/Who to contact/){
    #print $_->as_text . "\n";
    my @vals = split /:/, $_->as_text;
    foreach my $i (0 .. $#vals) {
      if ($vals[$i] =~ /PrimaryContact/){
		  $contact=$vals[$i+1];
      } 
    }
 }
}
#print $dataSourceName . "\n";
#print $displayName . "\n";
#print $shortDisplayName . "\n";
#print $shortAttribution . "\n";
#print $datasetSummary . "\n";
#print $datasetDescription . "\n";
#print $contact . "\n";

open O1, ">$dataSourceName.xml";
print O1 <<EOL;
    <datasetPresenter name="$dataSourceName" projectName="$project">
    <displayName><![CDATA[$displayName]]></displayName>
    <shortDisplayName><![CDATA[$shortDisplayName]]></shortDisplayName>
    <shortAttribution><![CDATA[$shortAttribution]]></shortAttribution>
    <summary><![CDATA[$datasetSummary]]></summary>
    <description><![CDATA[$datasetDescription]]></description>
    <protocol></protocol>
    <caveat></caveat>
    <acknowledgement></acknowledgement>
    <releasePolicy></releasePolicy>
    <history buildNumber="$buildNumber"/>
    <primaryContactId>$contact</primaryContactId>
    <link>
      <text>></text>
      <url><![CDATA[]]></url>
    </link>
    <pubmedId></pubmedId>
EOL
if($dataType=~/rnaSeq/){
print O1 <<EOL;
    <templateInjector className="org.apidb.apicommon.model.datasetInjector.RNASeq">
      <prop name="switchStrandsGBrowse">false</prop>
      <prop name="switchStrandsProfiles">false</prop>
      <prop name="isEuPathDBSite">true</prop>
      <prop name="isAlignedToAnnotatedGenome">true</prop>
      <prop name="isTimeSeries">TODO</prop>
      <prop name="showIntronJunctions">true</prop>
      <prop name="includeInUnifiedJunctions">true</prop>
      <prop name="hasMultipleSamples">TODO</prop>
      <prop name="hasFishersExactTestData">TODO</prop>
      <prop name="optionalQuestionDescription"></prop>
      <prop name="graphType">bar</prop>
      <prop name="graphColor">brown</prop>
      <prop name="graphForceXLabelsHorizontal"></prop>
      <prop name="graphBottomMarginSize"></prop>
      <prop name="graphSampleLabels"></prop>
      <prop name="graphPriorityOrderGrouping">0</prop>
      <prop name="graphXAxisSamplesDescription"><![CDATA[]]></prop>
      <prop name="isDESeq">TODO</prop>
      <prop name="isDEGseq">TODO</prop>
      <prop name="includeProfileSimilarity">false</prop>
      <prop name="profileTimeShift"></prop>
    </templateInjector>
EOL
}elsif($dataType=~/SNP/){
print O1 <<EOL;
    <templateInjector className="org.apidb.apicommon.model.datasetInjector.IsolatesHTS">
        <prop name="hasCNVData">TODO</prop>
    </templateInjector>
EOL
}elsif($dataType=~/chipSeq/){
print O1 <<EOL;
    <templateInjector className="org.apidb.apicommon.model.datasetInjector.ChIPSeq">
        <prop name="hasCalledPeaks">TODO</prop>
        <prop name="key"></prop>
        <prop name="subTrackAttr">name</prop>
    </templateInjector>
EOL
}elsif($dataType=~/massSpec/){
print O1 <<EOL;
   <templateInjector className="org.apidb.apicommon.model.datasetInjector.ProteinExpressionMassSpec">
      <prop name="species">$org</prop>
      <prop name="optionalOrganismAbbrev"></prop>
      <prop name="hasPTMs">TODO</prop>
    </templateInjector>
EOL
}elsif($dataType=~/chipChip/){
print O1 <<EOL;
    <templateInjector className="org.apidb.apicommon.model.datasetInjector.ChIPChip">
        <prop name="subTrackAttr">TODO</prop>
        <prop name="key"></prop>
        <prop name="hasCalledPeaks">TODO</prop>
    </templateInjector>
EOL
}
print O1 "</datasetPresenter>\n";
