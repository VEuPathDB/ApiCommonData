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
  # GUS4_STATUS | Study.Study                    | auto   | broken
  # GUS4_STATUS | Dots.Isolate                   | auto   | absent
  # GUS4_STATUS | DeprecatedTables               | auto   | absent
  # GUS4_STATUS | Pathway                        | auto   | absent
  # GUS4_STATUS | DoTS.SequenceVariation         | auto   | broken
  # GUS4_STATUS | RNASeq Junctions               | auto   | absent
  # GUS4_STATUS | Simple Rename                  | auto   | absent
  # GUS4_STATUS | ApiDB Tuning Gene              | auto   | absent
  # GUS4_STATUS | Rethink                        | auto   | absent
  # GUS4_STATUS | dots.gene                      | manual | unreviewed
die 'This file has broken or unreviewed GUS4_STATUS rules.  Please remove this line when all are fixed or absent';
#^^^^^^^^^^^^^^^^^^^^^^^^^ End GUS4_STATUS ^^^^^^^^^^^^^^^^^^^^
use strict;

use lib "$ENV{GUS_HOME}/lib/perl";

use Tie::IxHash;
use GUS::Supported::GusConfig;
use GUS::ObjRelP::DbiDatabase;

my %hash;
tie %hash, 'Tie::IxHash';
my $gusConfigFile;

my $usage = "generate_bam_conf.pl gus_config_file project_id\n";

my $gusConfigFile = shift or die $usage;
my $project_id = shift or die $usage;

$project_id = lc $project_id;

open(BAM,   '>'. $project_id . '_bam.conf'); 
open(BAMCT, '>'. $project_id . '_bam_category.conf'); 


my $gusconfig = GUS::Supported::GusConfig->new($gusConfigFile);

my $db = GUS::ObjRelP::DbiDatabase->new($gusconfig->getDbiDsn(),
                                        $gusconfig->getDatabaseLogin(),
                                        $gusconfig->getDatabasePassword(),
                                        0,0,1,
                                        $gusconfig->getCoreSchemaName());

my $dbh = $db->getQueryHandle(0);

my $sql =<<EOL;
SELECT distinct s.name, var.strain
FROM   study.study s,
       study.biomaterial b,
       rad.studybiomaterial sb,
       dots.seqvariation var
WHERE  sb.study_id = s.study_id
   AND sb.bio_material_id = b.bio_material_id
   AND var.external_database_release_id = b.external_database_release_id
ORDER BY s.name, var.strain
EOL

my $sth = $dbh->prepareAndExecute($sql);

while(my ($study,$strain) = $sth->fetchrow_array()) {
   push @{$hash{$study}}, $strain;
}

my $count = 0;
while(my($study, $strains) = each %hash) {
  $study =~ /^([^_]+)_(.*)$/;  # study: pfal3D7_Sanger_HTS_Isolates
  if($count == 0) {
    print BAMCT qq/category tables = 'Population Biology: HTS SNPs: $study' 'Coverage_Xyplot  Coverage_Density Alignment' '@$strains'\n/;
  } else {
    print BAMCT qq/   'Population Biology: HTS SNPs: $study' 'Coverage_Xyplot  Coverage_Density Alignment' '@$strains'\n/;
  }
  $count++;
}

while(my($study, $strains) = each %hash) {

  $study =~ /^([^_]+)_(.*)$/;  # study: pfal3D7_Sanger_HTS_Isolates
  foreach my $strain(@$strains) {

    print BAM <<EOL;
[$study\_$strain:database]
db_adaptor   = Bio::DB::Sam
db_args      = sub { { -bam => \$CFG->bam_file_path. '/$2/$strain/result.bam' } }

EOL
  }

}

while(my($study, $strains) = each %hash) {
  my $category = "Population Biology: HTS SNPs: $study";

  foreach my $strain(@$strains) {
    print BAM <<EOL;
[$study\_$strain\_CoverageXyplot]
feature        = coverage
database       = $study\_$strain
glyph          = wiggle_xyplot
scale          = both
height         = 50 
fgcolor        = blue 
bicolor_pivot  = 2  
pos_color      = blue 
neg_color      = red
label          = 0  
key            = $strain
category       = $category

EOL
  }

  # print density conf
  foreach my $strain(@$strains) {
    print BAM <<EOL;
[$study\_$strain\_CoverageDensity]
feature        = coverage
glyph          = wiggle_density
database       = $study\_$strain
height         = 30
fgcolor        = blue
bicolor_pivot  = 2
pos_color      = blue
neg_color      = red
label          = 0
key            = $strain
category       = $category

EOL
  }

  # print alignment conf
  my ($aligned_genome) = $study =~ /^([^_]+)_/;

  foreach my $strain(@$strains) {
    print BAM <<EOL;
[$study\_$strain\_Alignment]
feature        = read_pair
glyph          = segments
database       = $study\_$strain
draw_target    = 1
show_mismatch  = 1
mismatch_color = coral
bgcolor        = cornflowerblue
fgcolor        = black
height         = 3
label density  = 1
bump           = fast
connector      = dashed
key            = $strain ($aligned_genome aligned) [viewable under 3k]
category       = $category

[$study\_$strain\_Alignment:3000]
hide           = 1

EOL
  }

}


## category|study|strain strain ...
__DATA__
Population Biology: D. High Throughput Sequencing (HTS) SNPs - Sanger Isolates|pfal3D7_Sanger_HTS_Isolates|7G8 CS2 GB4 T9_94 V1_S
Population Biology: E. High Throughput Sequencing (HTS) SNPs - Broad Isolates|pvivSaI1_Broad_HTS_Isolates|Brazil_I India_VII Mauritania_I North_Korean
