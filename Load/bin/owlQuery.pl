#!/usr/bin/env perl
use strict;
use warnings;

use lib $ENV{GUS_HOME} . '/lib/perl';
use ApiCommonData::Load::OwlReader;
use Data::Dumper;
use File::Basename;

my ($ont, $query) = @ARGV;

my $ontdir = $ENV{PROJECT_HOME} . "/ApiCommonData/Load/ontology/release/production";

unless($ont){
	opendir(DH, $ontdir);
	my @onts = sort map { basename($_, ".owl") } grep  { /\.owl$/ } readdir(DH);
	closedir(DH);
	my @ids = 1 .. scalar @onts;
	my %choice;
	@choice{@ids} = @onts;
	printf("Choose owl:\n%s\nEnter number => ", join("\n", map { sprintf("%d\t%s", $_, $choice{$_}) } sort {$a <=> $b} keys %choice));
	my $opt;
	do{
		if($opt){ print "Invalid choice\nEnter number => "; }
		$opt = <>;
		chomp $opt if $opt;
		unless($opt){ print "\n"; exit; }
	}while($opt && !$choice{$opt});
	$ont = $choice{$opt};
}


my $owlFile;
if(-e $ont){
	$owlFile = $ont;
}
else {
	$owlFile = sprintf("%s/%s.owl", $ontdir, $ont);
}

my $owl = ApiCommonData::Load::OwlReader->new($owlFile);

unless($query){
	my $queries = $owl->getQueries();
	closedir(DH);
	my @ids = 1 .. scalar keys %$queries;
	my %choice;
	@choice{@ids} = sort keys %$queries;
	printf("Choose query\n%s\nEnter number => ", join("\n", map { sprintf("%d\t%s", $_, $choice{$_}) } sort {$a <=> $b} keys %choice));
	my $opt;
	do{
		if($opt){ print "Invalid choice\nEnter number => "; }
		$opt = <>;
		chomp $opt if $opt;
		unless($opt){ print "\n"; exit; }
	}while($opt && !$choice{$opt});
	$query = $choice{$opt};
}

if($query eq 'rel'){
	my $lines = $owl->getRelationships();
	foreach my $line (@$lines){
		printf("%s\n", join("\t", @$line));
	}
}
if($query eq 'terms'){
	my $it = $owl->execute('get_column_sourceID');
	my @fields = qw/sourceID variable/;
	printf("%s\n", join("\t", @fields));
	while( my $row = $it->next ){
		my $cols = $row->{vars} ? $row->{vars}->as_sparql : ""  ;
    my $uri = $row->{entity}->as_hash()->{iri}|| $row->{entity}->as_hash()->{URI};
    my $sid = $owl->getSourceIdFromIRI($uri);
		printf("%s\n", join("\t", $sid, $cols));
	}
}
elsif($query eq 'order'){
	my $h = $owl->getDisplayOrder();
	while(my ($k, $v) = each %$h){
		printf("%s\n", join("\t", $k, $v));
	}
}
elsif($query eq 'test'){
	my $it = $owl->execute('all_subclasses', {ENTITY=>'<http://purl.obolibrary.org/obo/EUPATH_0015399>'});
	my @fields = $it->binding_names;
	printf("%s\n", join("\t", @fields));
	while( my $row = $it->next ){
		my @vals = map { $row->{$_} ? $row->{$_}->as_sparql : "" } @fields;
		printf("%s\n", join("\t", @vals));
	}
}
elsif($query eq 'sidbytype'){
  my %categories = (
    household => '<http://purl.obolibrary.org/obo/PCO_0000024>',
    observation => '<http://purl.obolibrary.org/obo/EUPATH_0000738>',
    participant => '<http://purl.obolibrary.org/obo/EUPATH_0000096>',
    sample => '<http://purl.obolibrary.org/obo/EUPATH_0000609>'
  );

  my %iri;
  while( my($cat, $ent) = each %categories){
  	my $it = $owl->execute('all_subclasses', {ENTITY=>$ent});
  	while( my $row = $it->next ){
      my $uri = $row->{entity}->as_hash()->{iri}|| $row->{entity}->as_hash()->{URI};
      my $sid = basename($owl->getSourceIdFromIRI($uri));
      $iri{$sid} = $cat;
    }
  }
  printf("$_\t$iri{$_}\n") for sort { $iri{$a} cmp $iri{$b} } keys %iri;
}
else {
	my $it = $owl->execute($query);
	my @fields = $it->binding_names;
	printf("%s\n", join("\t", @fields));
	while( my $row = $it->next ){
		my @vals = map { $row->{$_} ? $row->{$_}->as_sparql : "" } @fields;
		printf("%s\n", join("\t", @vals));
	}
}
	
