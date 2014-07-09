#!/usr/bin/perl
#vvvvvvvvvvvvvvvvvvvvvvvvv GUS4_STATUS vvvvvvvvvvvvvvvvvvvvvvvvv
  # GUS4_STATUS | SRes.OntologyTerm              | auto   | absent
  # GUS4_STATUS | SRes.SequenceOntology          | auto   | absent
  # GUS4_STATUS | Study.OntologyEntry            | auto   | absent
  # GUS4_STATUS | SRes.GOTerm                    | auto   | absent
  # GUS4_STATUS | Dots.RNAFeatureExon            | auto   | absent
  # GUS4_STATUS | RAD.SageTag                    | auto   | absent
  # GUS4_STATUS | RAD.Analysis                   | auto   | absent
  # GUS4_STATUS | ApiDB.Profile                  | auto   | absent
  # GUS4_STATUS | Study.Study                    | auto   | absent
  # GUS4_STATUS | Dots.Isolate                   | auto   | absent
  # GUS4_STATUS | DeprecatedTables               | auto   | absent
  # GUS4_STATUS | Pathway                        | auto   | absent
  # GUS4_STATUS | DoTS.SequenceVariation         | auto   | absent
  # GUS4_STATUS | RNASeq Junctions               | auto   | absent
  # GUS4_STATUS | Simple Rename                  | auto   | absent
  # GUS4_STATUS | ApiDB Tuning Gene              | auto   | absent
  # GUS4_STATUS | Rethink                        | auto   | absent
  # GUS4_STATUS | dots.gene                      | manual | unreviewed
die 'This file has broken or unreviewed GUS4_STATUS rules.  Please remove this line when all are fixed or absent';
#^^^^^^^^^^^^^^^^^^^^^^^^^ End GUS4_STATUS ^^^^^^^^^^^^^^^^^^^^

use strict;
use lib "$ENV{GUS_HOME}/lib/perl";

use Getopt::Long;

use XML::Simple;

use  GUS::Community::FileTranslator;

use Tie::IxHash;

my ($help, $xmlFile, $translator);

my $PAGE = 'PaGE_5.1.6_modifiedConfOutput.pl';
my $MISSING_VALUE = 'NA';
my $USE_LOGGED_DATA = 1;


&GetOptions('help|h' => \$help,
            'xml_file=s' => \$xmlFile,
            'translator=s' => \$translator,
           );

unless(-e $xmlFile && -e $translator) {
  die "File [$xmlFile] does not exist";
}


my $analyses = &parseXmlInput($xmlFile);

foreach my $analysis (@$analyses) {
  my $args = $analysis->{arguments};

  my $pageInputFile = &makePageInput($args);

  &runPage($pageInputFile, $args);

  my $baseX;
  if($args->{isDataLogged}) {
    $baseX = $args->{baseX};
    die "baseX arg not defined when isDataLogged set to true" unless($baseX);
  }

  &translatePageOutput($pageInputFile, $translator, $baseX);
}

sub translatePageOutput {
  my ($pageInputFile, $translator, $baseX) = @_;

  my $pageOutputFile = $pageInputFile . "-gene_conf_list.txt";

  my $functionArgs = {baseX => $baseX};

  my $dataFile = $pageOutputFile . ".data";
  my $logFile =  $pageOutputFile . ".log";

  my $fileTranslator = eval { 
    GUS::Community::FileTranslator->new($translator, $logFile);
  };

  if ($@) {
    die "The mapping configuration file '$translator' failed the validation. Please see the log file $logFile";
  };

  $fileTranslator->translate($functionArgs, $pageOutputFile, $dataFile);
}

sub runPage {
  my ($pageIn, $args) = @_;

  my $pageOut = $pageIn;
  $pageOut =~ s/in$/out/;

  my $channels = $args->{numberOfChannels};
  my $isLogged = $args->{isDataLogged};
  my $isPaired = $args->{isDataPaired};
  my $levelConfidence = $args->{levelConfidence};
  my $minPrescence = $args->{minPrescence};

  my $statistic = '--' . $args->{statistic};

  my $design = "--design " . $args->{design} if($args->{design} && $channels == 2);

  my $isLoggedArg = $isLogged ? "--data_is_logged" : "--data_not_logged";
  my $isPairedArg = $isPaired ? "--paired" : "--unpaired";

  my $useLoggedData = $USE_LOGGED_DATA ? '--use_logged_data' : '--use_unlogged_data';

  my $pageCommand = "$PAGE --infile $pageIn --outfile $pageOut --output_gene_confidence_list --output_text --num_channels $channels $isLoggedArg $isPairedArg --level_confidence $levelConfidence $useLoggedData $statistic --min_presence $minPrescence --missing_value $MISSING_VALUE $design";

  my $systemResult = system($pageCommand);

  unless($systemResult / 256 == 0) {
    die "Error while attempting to run PaGE:\n$pageCommand";
  }

  # PaGE appends .txt to the output
  return $pageOut . ".txt";
}

sub makePageInput {
  my ($args) = @_;

  my $fn = $args->{inputFile};
  open(FILE, $fn) or die "Cannot open file $fn for reading: $!";

  my $header;
  chomp($header = <FILE>);

  my $headerIndexHash = &processHeader($header);

  my $conditions = &conditions($args->{conditions}, $headerIndexHash);

  my $outputFile = &outputFileName($conditions);

  open(OUT, "> $outputFile") or die "Cannot open file $outputFile for writing: $!";

  &printHeader($conditions, \*OUT);

  my @indexes;
  foreach my $c (keys %$conditions) {
    foreach my $r (@{$conditions->{$c}}) {
      my $index = $headerIndexHash->{$r};
      push @indexes, $index;
    }
  }


  while(<FILE>) {
    chomp;

    my @data = split(/\t/, $_);

    my @values = map {$data[$_]} @indexes;

    print OUT $data[0] . "\t" . join("\t", @values) . "\n";
  }

  close OUT;
  close FILE;

  return $outputFile;
}


sub printHeader {
  my ($conditions, $outFh) = @_;


  my @a;
  my $c = 0;
  foreach(keys %$conditions) {

    my $r = 1;
    foreach(@{$conditions->{$_}}) {
      push @a, "c" . $c . "r" . $r;
      $r++;
    }
    $c++;
  }
  print  $outFh "id\t" . join("\t", @a) . "\n";  
}


sub outputFileName {
  my ($conditions) = @_;

  my @names = keys %$conditions;

  my $treatment = $names[1];
  my $control = $names[0];

  return $treatment . "_vs_" . $control . ".page";;
}



sub conditions {
  my ($input, $indexHash) = @_;

  my %rv;
  tie %rv, "Tie::IxHash";

  return \%rv unless($input);

  unless(ref($input) eq 'ARRAY') {
    die "Illegal param to method call [standardParametervalues].  Expected ARRAYREF";
  }

  foreach my $lg (@$input) {
    my ($name, $link) = split(/\|/, $lg);

    push @{$rv{$name}}, $link;
  }

  unless(scalar keys %rv == 2) {
    die "Expecting 2 state comparison... expected 2 conditions";
  }


  return \%rv;
}



sub processHeader {
  my ($header)  = @_;

  my %rv;

  my @a = split(/\t/, $header);
  for(my $i = 0; $i < scalar @a; $i++) {
    my $value = $a[$i];

    $rv{$value} = $i;
  }

  return \%rv;
}

sub parseXmlInput {
  my ($xmlFile) = @_;

  my $xml = XMLin($xmlFile,  'ForceArray' => 1);

  my $defaults = $xml->{defaultArguments}->[0]->{property};
  my $analyses = $xml->{analysis};

  foreach my $analysis (@$analyses) {
    my $args = {};

    foreach my $default (keys %$defaults) {
      my $defaultValue = $defaults->{$default}->{value};

      if(ref($defaultValue) eq 'ARRAY') {
        my @ar = @$defaultValue;
        $args->{$default} = \@ar;
      }
      else {
        $args->{$default} = $defaultValue;
      }
    }

    my $properties = $analysis->{property};

    foreach my $property (keys %$properties) {
      my $value = $properties->{$property}->{value};

      if(ref($value) eq 'ARRAY') {
        push(@{$args->{$property}}, @$value);
      }
      else {
        $args->{$property} = $value;
      }
    }

    $analysis->{arguments} = $args;
  }
  return $analyses;
}




1;

