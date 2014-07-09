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

#script to load Giardia phylogenetic trees

use strict;
use warnings;
use lib "$ENV{GUS_HOME}/lib/perl";

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
    SELECT source_id FROM dots.GeneFeature
    WHERE source_id = ?
EOF

  $sth0->execute($src_id);
  # load tree only if source_id exists in dots.GeneFeature table
  if ($sth0->fetchrow_array) {
    $sth->execute($src_id, `cat $_`, '');
  }
}

$dbh->commit;

