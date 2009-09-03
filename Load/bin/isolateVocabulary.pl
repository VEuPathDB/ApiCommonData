#!/usr/bin/perl

use strict;

use Getopt::Long;

use ApiCommonData::Load::IsolateVocabulary::Reader::SqlReader;
use ApiCommonData::Load::IsolateVocabulary::Reader::XmlReader;

use ApiCommonData::Load::IsolateVocabulary::Reporter;
use ApiCommonData::Load::IsolateVocabulary::Updater;
use ApiCommonData::Load::IsolateVocabulary::InsertMappedValues;

my $subCommand = $ARGV[0];

my ($help, $gusConfigFile, $type, $xmlFile);

&GetOptions('help|h' => \$help,
            'gus_config_file=s' => \$gusConfigFile,
            'type=s' => \$type,
            'xml_file=s' => \$xmlFile,
            );

&usage if($help);
&usage unless($subCommand eq 'report' || $subCommand eq 'insert');

if(!$gusConfigFile || !$type || !$xmlFile) {
  &usage("Error: Required Argument omitted");
}

my $xmlReader = ApiCommonData::Load::IsolateVocabulary::Reader::XmlReader->new($xmlFile);
my $xmlTerms = $xmlReader->extract();

my $sqlReader = ApiCommonData::Load::IsolateVocabulary::Reader::SqlReader->new($gusConfigFile, $type);
my $sqlTerms = $sqlReader->extract();

if($subCommand eq 'report') {
  my $reporter = ApiCommonData::Load::IsolateVocabulary::Reporter->new($gusConfigFile, $xmlTerms, $sqlTerms, $type);
  $reporter->report();
}

#if($subCommand eq 'update') {
#  my $updater = ApiCommonData::Load::IsolateVocabulary::Updater->new($gusConfigFile, $type, $xmlTerms);
#  $updater->update();
#}

if($subCommand eq 'insert') {
  my $inserter = ApiCommonData::Load::IsolateVocabulary::InsertMappedValues->new($gusConfigFile, $type, $xmlTerms, $sqlTerms);
  $inserter->insert();
}


sub usage {
  my ($m) = @_;

  print STDERR "$m\n\n" if($m);
  print STDERR "perl isolateVocabulary.pl update|report --gus_config_file=s --type=s --xml_file=f\n";
  exit;
}
