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


my $owl = <<EOF;
<?xml version="1.0"?>
<rdf:RDF xmlns="http://purl.obolibrary.org/obo/microbiome.owl#"
     xml:base="http://purl.obolibrary.org/obo/microbiome.owl"
     xmlns:obo="http://purl.obolibrary.org/obo/"
     xmlns:owl="http://www.w3.org/2002/07/owl#"
     xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#"
     xmlns:xml="http://www.w3.org/XML/1998/namespace"
     xmlns:xsd="http://www.w3.org/2001/XMLSchema#"
     xmlns:rdfs="http://www.w3.org/2000/01/rdf-schema#">
    <owl:Class rdf:about="http://purl.obolibrary.org/obo/ENVO_01000739">
        <obo:EUPATH_0000755 rdf:datatype="http://www.w3.org/2001/XMLSchema#string">env_feature</obo:EUPATH_0000755>
    </owl:Class>
</rdf:RDF>
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
done_testing;
