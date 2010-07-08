#!/usr/bin/perl

use strict;

use Getopt::Long;

use ApiCommonData::Load::IsolateVocabulary::Reader::SqlReader;
use ApiCommonData::Load::IsolateVocabulary::Reader::XmlReader;

use ApiCommonData::Load::IsolateVocabulary::Reporter;
use ApiCommonData::Load::IsolateVocabulary::Updater;
use ApiCommonData::Load::IsolateVocabulary::InsertMappedValues;

my ($help, $gusConfigFile, $type, $xmlFile, $vocabFile);

&GetOptions('help|h' => \$help,
            'gus_config_file=s' => \$gusConfigFile,
            'type=s' => \$type,
            'xml_file=s' => \$xmlFile,
            'vocab_file=s' => \$vocabFile,
            );

&usage if($help);

$gusConfigFile = $ENV{GUS_HOME} . "/config/gus.config" unless($gusConfigFile);

if(!$gusConfigFile || !$type || !$xmlFile || $vocabFile) {
  &usage("Error: Required Argument omitted");
}

my $xmlReader = ApiCommonData::Load::IsolateVocabulary::Reader::XmlReader->new($xmlFile);
my $xmlTerms = $xmlReader->extract();

my $vocabFileReader = ApiCommonData::Load::IsolateVocabulary::Reader::VocabFileReader->new($vocabFile, $gusConfigFile, $type);
my $vocabTerms = $vocabFileReader->extract();

my $reporter = ApiCommonData::Load::IsolateVocabulary::Reporter->new($gusConfigFile, $xmlTerms, $vocabTerms, $type);

$reporter->report();


sub usage {
  my ($m) = @_;

  print STDERR "$m\n\n" if($m);
  print STDERR "perl isolateVocabulary.pl --gus_config_file=s --type=s --xml_file=f --vocab_file=f\n";
  print STDERR "

Report terms used in isolates loaded into the database but not found in the provided vocabulary file.

";
  exit;
}
