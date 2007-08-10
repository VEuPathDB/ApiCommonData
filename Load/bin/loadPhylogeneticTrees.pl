#!/usr/bin/perl

use strict;
use warnings;

use Getopt::Long;
use GUS::Supported::GusConfig;
use GUS::ObjRelP::DbiDatabase;

use File::Find;
use File::Basename;

my ($gusConfigFile,$atvFilesPath,$verbose);
&GetOptions("gusConfigFile=s" => \$gusConfigFile,
            'atvFilesPath=s' => \$atvFilesPath,
	    "verbose!" => \$verbose,
	   );

my $gusconfig = GUS::Supported::GusConfig->new($gusConfigFile);

my $db = GUS::ObjRelP::DbiDatabase->new($gusconfig->getDbiDsn(),
                                        $gusconfig->getDatabaseLogin(),
                                        $gusconfig->getDatabasePassword(),
                                        $verbose,0,1,
                                        $gusconfig->getCoreSchemaName());
my $dbh = $db->getQueryHandle(0);


my @infiles;

find( {
       follow => 1,
       wanted => sub { push @infiles, "$File::Find::dir/$_" if /\.atv/ }
      },
  $atvFilesPath
);


my $sth = $dbh->prepare(<<EOF);
    INSERT INTO apidb.PhylogeneticTree
    VALUES (?,?,?)
EOF

map { $sth->execute(basename($_, '.atv'), `cat $_`, '') } @infiles;

$dbh->commit;

