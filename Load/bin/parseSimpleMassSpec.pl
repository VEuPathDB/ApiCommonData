#!/usr/bin/perl

use strict;

use ApiCommonData::Load::MassSpecTransform;

use CBIL::Util::PropertySet;

use Getopt::Long;

my ($help, $file, $config, $debug);

&GetOptions('help|h' => \$help,
            'data_file=s' => \$file,
            'config_file=s' => \$config,
            'debug' => \$debug,
    );


my @properties = (#["proteinIdColumn"],
                  #["geneSourceIdColumn"],
                  #["peptideSequenceColumn"],
                  #["peptideSpectrumColumn"],
                  #["peptideIonScoreColumn"],
                  ["skipLines"],
                  ["delimiter","\t"],
                  ["trimPeptideRegex", "^\w*\.(\w+)\.\w*$"],
                  ["headerRegex"],
    );
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
            debug => $debug
};

my $mst = ApiCommonData::Load::MassSpecTransform->new($args);


$mst->readFile();


1;


