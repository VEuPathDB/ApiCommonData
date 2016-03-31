#!/usr/bin/perl
use strict;

use lib "$ENV{GUS_HOME}/lib/perl";
use Getopt::Long;
use GUS::Supported::GusConfig;
use GUS::ObjRelP::DbiDatabase;

my $usage =<<EOL;
   compareDatasources.pl --gusConfigFile gus.config --workflowVersion workflow_version
   the script is used to find datasources loaded into "-inc" instance rather than "-rbld"
  
   gusConfigFile:   gus.config is the config for inc instance, e.g. plas-inc
   workflowVersion: rbld workflow version, e.g. 26 for plasmo gus4 rbld workflow

   NOTE!!! gus.config is about "inc" instance, workflow version is about "rbld"  

   for instance:
   compareDatasources.pl --gusConfigFile gus.config --workflowVersion 26 
EOL

my ($gusConfigFile, $workflowVersion);
&GetOptions( 'gusConfigFile=s'   => \$gusConfigFile,
             'workflowVersion=s' => \$workflowVersion,
           );

die $usage unless $gusConfigFile && $workflowVersion;

my $gusconfig = GUS::Supported::GusConfig->new($gusConfigFile);

my $db = GUS::ObjRelP::DbiDatabase->new($gusconfig->getDbiDsn,
                                        $gusconfig->getDatabaseLogin,
                                        $gusconfig->getDatabasePassword,
                                        1, 0, 1,
                                        $gusconfig->getCoreSchemaName);

my $dbh = $db->getQueryHandle(0);
my $project = $gusconfig->getProject;
my %hash_rbld;

my $dir = "/eupath/data/EuPathDB/workflows/$project/$workflowVersion/steps";
opendir DIR, $dir ;

my @fs = grep(/insertDataset/, readdir(DIR));
close DIR;

foreach my $f(@fs) {

  open F, "$dir/$f/step.log";
  while(<F>) {
    $hash_rbld{$1} = $1 if(/--dataSourceName '(.*?)'/);
  }
  close F;
}

my $sql = "select distinct name from apidb.datasource order by name";

my $sth = $dbh->prepare($sql);
$sth->execute; 

while(my $row = $sth->fetchrow_arrayref) {
  my $name_inc = $row->[0];
  print "$name_inc\n" unless (exists $hash_rbld{$name_inc}) 
}

$sth->finish();
$dbh->disconnect();
