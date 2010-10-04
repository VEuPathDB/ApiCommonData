#!/usr/bin/perl


#########################################################################
#########################################################################
#
# A wrapper to intall gus schema and apidb schema by one command.
# intall gusSchema -> install apidb schema -> bld gus objects
#
#########################################################################
#########################################################################

use strict;
use lib "$ENV{GUS_HOME}/lib/perl";
use Getopt::Long;
use GUS::Supported::GusConfig;

my ($gusConfigFile, $drop, $create, $db);

&GetOptions("gusConfigFile=s" => \$gusConfigFile,
	   "drop!" => \$drop,
	   "create!" => \$create,
	   "db=s" => \$db);

if (!$db || !($drop || $create) || ($drop && $create)) {
  die "usage: apidbPrepareInstance --db database [--drop | --create] [--gusConfigFile gus_config_file]\n";
}

$gusConfigFile = $ENV{GUS_HOME} . "/config/gus.config" unless($gusConfigFile);

if ($create){

    my $gusInstall='build GUS install -installDBSchema';

    system($gusInstall);

    my $status = $? >>8;

    die "Failed with status '$status running cmd: $gusInstall'" if $status;

    my $apidbInstall="installApidbSchema --db $db --create";

    system($apidbInstall);

    my $status = $? >>8;

    die "Failed with status '$status running cmd: $apidbInstall'" if $status;

    my $gusBld='build GUS install -append';

    system($gusBld);

    my $status = $? >>8;

    die "Failed with status '$status running cmd: $gusBld'" if $status;

}elsif($drop){

    my $gusDrop='';

    system($gusDrop);

    my $status = $? >>8;

    die "Failed with status '$status running cmd: $gusDrop'" if $status;

    my $apidbDrop="installApidbSchema --db $db --drop";

    system($apidbDrop);

    my $status = $? >>8;

    die "Failed with status '$status running cmd: $apidbDrop'" if $status;
    
}


exit 1;



