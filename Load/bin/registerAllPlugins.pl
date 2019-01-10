#!/usr/bin/perl

use strict;

use lib $ENV{GUS_HOME} . "/lib/perl";

use DBI;
use DBD::Oracle;

use GUS::Supported::GusConfig;

use Data::Dumper;

my $configFile = "$ENV{GUS_HOME}/config/gus.config";
my $config = GUS::Supported::GusConfig->new($configFile);

my $dbh = DBI->connect( $config->getDbiDsn(),
                        $config->getDatabaseLogin(),
                        $config->getDatabasePassword(),
    )
    || die "unable to open db handle to ", $config->getDbiDsn;

my $sql = "select name, ai.executable_md5 from core.algorithm a, core.algorithmimplementation ai
where ai.algorithm_id (+) = a.algorithm_id";

my %algorithms;
my %checkSums;

my $sh = $dbh->prepare($sql);
$sh->execute();

while(my ($name, $md5) = $sh->fetchrow_array()) {
  $algorithms{$name}++;
  $checkSums{$name}->{$md5}++ if($md5);
}$sh->finish;
$dbh->disconnect();


foreach my $pluginPath (glob "$ENV{GUS_HOME}/lib/perl/*/*/Plugin/*.pm") {
  my $failedCompile = system("perl -c -I $ENV{GUS_HOME}/lib/perl $pluginPath >/dev/null 2>&1");
  next if $failedCompile;

  my $module = $pluginPath;
  $module =~ s/\//::/g;
  $module =~ /lib::perl::(.+)\.pm$/;
  $module = $1; 
 
  # if the database doesn't know about the Plugin, register it
  if(!$algorithms{$module}) {
    system("ga +create $module --commit");
    next;
  }

  my $md5 = `md5sum $pluginPath | cut -f 1 -d ' '`;
  chomp $md5;
  
  # wer're done if we have a match
  if($checkSums{$module}->{$md5}) {
    next;
  }

  # if the database doesn't know about the Version of the plugin, register it
  system("ga +update $module --commit");
}

1;
