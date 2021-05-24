use strict;
use warnings;

use lib "$ENV{GUS_HOME}/lib/perl";

use Test::More;
use Test::Exception;
use File::Temp qw/tempdir/;
use File::Slurp qw/write_file/;
use File::Path qw/make_path/;

use FindBin qw/$Bin/;
use Env qw/PROJECT_HOME SPARQLPATH/;
use ApiCommonData::Load::OntologyMapping;
use ApiCommonData::Load::OwlReader;


my $dir = tempdir(CLEANUP => 1);
$PROJECT_HOME = ""; 

my $owlHead = <<EOF;
<?xml version="1.0"?>
<rdf:RDF xmlns="http://purl.obolibrary.org/obo/microbiome.owl#"
     xml:base="http://purl.obolibrary.org/obo/microbiome.owl"
     xmlns:obo="http://purl.obolibrary.org/obo/"
     xmlns:owl="http://www.w3.org/2002/07/owl#"
     xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#"
     xmlns:xml="http://www.w3.org/XML/1998/namespace"
     xmlns:xsd="http://www.w3.org/2001/XMLSchema#"
     xmlns:rdfs="http://www.w3.org/2000/01/rdf-schema#">
EOF
my $owlTail = <<EOF;
</rdf:RDF>
EOF

my $owl = <<"EOF";
$owlHead
    <owl:Class rdf:about="http://purl.obolibrary.org/obo/ENVO_01000739">
        <obo:EUPATH_0000755 rdf:datatype="http://www.w3.org/2001/XMLSchema#string">env_feature</obo:EUPATH_0000755>
    </owl:Class>
$owlTail
EOF
write_file("$dir/microbiome.owl", $owl);

dies_ok {ApiCommonData::Load::OntologyMapping->fromOwl('not a path to any file') } "Arg is a path or name of the owl in production directory";
dies_ok {ApiCommonData::Load::OntologyMapping->fromOwl("$dir/microbiome.owl") } "Needs SPARQLPATH"; 
($SPARQLPATH = $Bin) =~ s{Load/t.*}{Load/lib/SPARQL};
ok(ApiCommonData::Load::OntologyMapping->fromOwl("$dir/microbiome.owl"), 'read from path');

$PROJECT_HOME = "$dir/ph";
my $pd = "$PROJECT_HOME/ApiCommonData/Load/ontology/release/production";
make_path $pd;
write_file("$pd/microbiome.owl", $owl);
ok(ApiCommonData::Load::OntologyMapping->fromOwl("microbiome"), 'read from PROJECT_HOME');

my $xml = <<EOF;
<ontologyMappings>
  <ontologySource>OBI</ontologySource>
  <ontologySource>YOLO</ontologySource>

  <ontologyTerm source_id="ENVO_01000739" type="characteristicQualifier" parent="Source">
    <name>env_feature</name>
  </ontologyTerm>
</ontologyMappings>
EOF

my ($ontologySourcesOwl, $ontologyMappingOwl) = ApiCommonData::Load::OntologyMapping->fromOwl("$dir/microbiome.owl")->asSourcesAndMapping;

is_deeply($ontologySourcesOwl, {}, "no sources from owls");
ok($ontologyMappingOwl->{env_feature}{characteristicQualifier}, "in the owl there is a characteristic qualifier, env feature");

my ($ontologySourcesXml, $ontologyMappingXml) = ApiCommonData::Load::OntologyMapping->fromXml(\$xml)->asSourcesAndMapping;
is_deeply($ontologySourcesXml, {obi => 1, yolo => 1}, "sources at the top of the XML");
ok($ontologyMappingXml->{env_feature}{characteristicQualifier}, "in the xml there is a characteristic qualifier, env feature");

diag explain { owl => $ontologyMappingOwl->{env_feature}, xml => $ontologyMappingXml->{env_feature}} ;
is_deeply($ontologyMappingOwl->{env_feature}{source_id}, $ontologyMappingXml->{env_feature}{source_id}, "Owl and Xml agree on source_id");

my $gemsOwl = <<"EOF";
$owlHead
    <owl:Class rdf:about="http://purl.obolibrary.org/obo/EUPATH_0010075">
        <rdfs:subClassOf rdf:resource="http://purl.obolibrary.org/obo/EUPATH_0000649"/>
        <obo:EUPATH_0000274 rdf:datatype="http://www.w3.org/2001/XMLSchema#string">17</obo:EUPATH_0000274>
        <obo:EUPATH_0000755 rdf:datatype="http://www.w3.org/2001/XMLSchema#string">F5_HT1</obo:EUPATH_0000755>
        <obo:EUPATH_0000755 rdf:datatype="http://www.w3.org/2001/XMLSchema#string">F7_HT1</obo:EUPATH_0000755>
        <obo:EUPATH_0001001 rdf:datatype="http://www.w3.org/2001/XMLSchema#string">GEMS1_Case_control_Study_data_June2018.csv</obo:EUPATH_0001001>
        <obo:EUPATH_0001002 rdf:datatype="http://www.w3.org/2001/XMLSchema#string">Participant</obo:EUPATH_0001002>
        <obo:EUPATH_0001003 rdf:datatype="http://www.w3.org/2001/XMLSchema#string">NA</obo:EUPATH_0001003>
        <obo:EUPATH_0001004 rdf:datatype="http://www.w3.org/2001/XMLSchema#string">NA</obo:EUPATH_0001004>
        <obo:EUPATH_0001005 rdf:datatype="http://www.w3.org/2001/XMLSchema#string">variable</obo:EUPATH_0001005>
        <obo:EUPATH_0001008 rdf:datatype="http://www.w3.org/2001/XMLSchema#string">cm</obo:EUPATH_0001008>
        <obo:EUPATH_0001009 rdf:datatype="http://www.w3.org/2001/XMLSchema#string">http://purl.obolibrary.org/obo/UO_0000015</obo:EUPATH_0001009>
        <obo:EUPATH_0001010 rdf:datatype="http://www.w3.org/2001/XMLSchema#string">GEMS1 Case Control</obo:EUPATH_0001010>
        <obo:EUPATH_0001011 rdf:datatype="http://www.w3.org/2001/XMLSchema#string">yes</obo:EUPATH_0001011>
        <obo:IAO_0000115 rdf:datatype="http://www.w3.org/2001/XMLSchema#string">Height at enrollment or 60 day follow-up; first measurement</obo:IAO_0000115>
        <rdfs:label rdf:datatype="http://www.w3.org/2001/XMLSchema#string">Height</rdfs:label>
    </owl:Class>
$owlTail
EOF
write_file("$dir/gems.owl", $gemsOwl);
my ($ontologySourcesGemsOwl, $ontologyMappingGemsOwl) = ApiCommonData::Load::OntologyMapping->fromOwl("$dir/gems.owl")->asSourcesAndMapping;
diag explain $ontologyMappingGemsOwl->{f5_ht1};
ok($ontologyMappingGemsOwl->{f5_ht1}{characteristicQualifier}{unit}, "unit label");
ok($ontologyMappingGemsOwl->{f5_ht1}{characteristicQualifier}{unitSourceId}, "unit IRI");
done_testing;
