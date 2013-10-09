#!/usr/bin/perl

use strict;

use CBIL::Util::PropertySet;

use Getopt::Long;

use Data::Dumper;

my ($help, $file, $config, $debug, $out);

&GetOptions('help|h' => \$help,
            'data_file=s' => \$file,
            'output_file=s' => \$out,
            'config_file=s' => \$config,
            'debug' => \$debug,
    );


my @properties = (#["proteinIdColumn"],
                  #["geneSourceIdColumn"],
                  #["peptideSequenceColumn"],
                  #["peptideSpectrumColumn"],
                  #["peptideIonScoreColumn"],
                  ["class", "ApiCommonData::Load::MassSpecTransform"],
                  ["skipLines"],
                  ["delimiter","\t"],
                  ["trimPeptideRegex", '^\w*\.(\w+)\.\w*$'],
                  ["headerRegex"],
    );


#TODO:  print usage if required args not provided

my $prop = CBIL::Util::PropertySet->new($config, \@properties, 1);

my $trimPeptideRegex = qr /$prop->{props}->{trimPeptideRegex}/;
my $headerRegex = qr /$prop->{props}->{headerRegex}/;
my $delimiter = qr/$prop->{props}->{delimiter}/;

my $args = {proteinIdColumn => $prop->{props}->{proteinIdColumn},
            geneSourceIdColumn => $prop->{props}->{geneSourceIdColumn},
            peptideSequenceColumn => $prop->{props}->{peptideSequenceColumn},
            peptideSpectrumColumn => $prop->{props}->{peptideSpectrumColumn},
            peptideIonScoreColumn => $prop->{props}->{peptideIonScoreColumn},
            skipLinesCount => $prop->{props}->{skipLines},
            delimiter => $delimiter,
            trimPeptideRegex => $trimPeptideRegex,
            headerRegex => $headerRegex,
            inputFile => $file,
            outputFile => $out,
            debug => $debug
};

my $class = $prop->{props}->{class};

eval "require $class";

my $mst = eval {
    $class->new($args);
  };

die "Could not create class $class" if $@;


$mst->readFile();

$mst->writeFile();

1;


