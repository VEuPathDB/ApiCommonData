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

use DBI;
use DBD::Oracle;
use lib "$ENV{GUS_HOME}/lib/perl";

use Getopt::Long;

use GUS::Community::FileTranslator;

use CBIL::Util::PropertySet;

my ($help, $xmlFile, $gusConfig, $logFile, $dataFile, $dataOut);

&GetOptions('help|h' => \$help,
            'xml_config=s' => \$xmlFile,
            'log=s' => \$logFile,
            'data_in=s' => \$dataFile,
            'gus_config_file=s' => \$gusConfig,
            'data_out=s' => \$dataOut,
            );

if($help || !$xmlFile || !$dataFile || !$dataOut) {
  print STDERR "usage: perl loadArrayDesignConfig.pl --xml_config <CONFIG> --data_in <DATA> --log <LOG> --data_out STRING [--gus_config_file] \n";
  exit();
}

unless($gusConfig) {
  $gusConfig = $ENV{GUS_HOME} . "/config/gus.config";
}

my @properties = ();
my $gusProp = CBIL::Util::PropertySet->new($gusConfig, \@properties, 1);

my $u = $gusProp->{props}->{databaseLogin};
my $pw = $gusProp->{props}->{databasePassword};
my $dsn = $gusProp->{props}->{dbiDsn};

my $dbh = DBI->connect($dsn, $u, $pw, {RaiseError => 1}) or die DBI::errstr;

my $fileTranslator = eval { 
  GUS::Community::FileTranslator->new($xmlFile, $logFile);
};

if ($@) {
  die "The mapping configuration file '$xmlFile' failed the validation. Please see the log file $logFile";
};

$fileTranslator->translate({dbh => $dbh}, $dataFile , $dataOut);


$dbh->disconnect();

1;
