#!/usr/bin/perl

#script to load Giardia phylogenetic trees

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


foreach (@infiles){
  my $src_id = 'GL50803_' . basename($_, '.atv');
  my $sth0 = $dbh->prepare(<<EOF);
    SELECT source_id FROM apidb.geneAttributes
    WHERE source_id = ?
EOF

  $sth0->execute($src_id);
  # load tree only if source_id exists in apidb.geneAttributes table
  if ($sth0->fetchrow_array) {
    $sth->execute($src_id, `cat $_`, '');
  }
}

$dbh->commit;

