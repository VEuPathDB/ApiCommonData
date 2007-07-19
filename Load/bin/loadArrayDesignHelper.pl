#!/usr/bin/perl

use strict;

use DBI;
use DBD::Oracle;

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

my $dbh = DBI->connect($dsn, $u, $pw) or die DBI::errstr;

my $fileTranslator = eval { 
  GUS::Community::FileTranslator->new($xmlFile, $logFile);
};

if ($@) {
  die "The mapping configuration file '$xmlFile' failed the validation. Please see the log file $logFile";
};

$fileTranslator->translate({dbh => $dbh}, $dataFile , $dataOut);


$dbh->disconnect();

1;
