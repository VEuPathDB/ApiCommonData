package ApiCommonData::Load::Plugin::InsertGeneFeatureLODScores;
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
  # GUS4_STATUS | Simple Rename                  | auto   | broken
  # GUS4_STATUS | ApiDB Tuning Gene              | auto   | absent
  # GUS4_STATUS | Rethink                        | auto   | absent
  # GUS4_STATUS | dots.gene                      | manual | unreviewed
die 'This file has broken or unreviewed GUS4_STATUS rules.  Please remove this line when all are fixed or absent';
#^^^^^^^^^^^^^^^^^^^^^^^^^ End GUS4_STATUS ^^^^^^^^^^^^^^^^^^^^
@ISA = qw(GUS::PluginMgr::Plugin);

use strict;
use warnings;

use GUS::PluginMgr::Plugin;

use GUS::Model::SRes::ExternalDatabase;
use GUS::Model::SRes::ExternalDatabaseRelease;
use GUS::Model::DoTS::GeneFeature;
use GUS::Model::ApiDB::GeneFeatureLodScore;
use GUS::Supported::Util;

# ----------------------------------------------------------
# Load Arguments
# ----------------------------------------------------------

sub getArgsDeclaration {
  my $argsDeclaration  =
    [
     fileArg({ name => 'file',
         descr => 'tab delimited file',
         constraintFunc=> undef,
         reqd  => 1,
         isList => 0,
         mustExist => 1,
         format => 'first column is the chromosome, second column is the centimorgan value, subsequent columns are LOD scores for every gene. One column for every gene. The plugin expects header in the file (which should contain the gene ids)',
       }),
     stringArg({ name => 'extDbName',
     descr => 'externaldatabase name that this dataset references',
     constraintFunc=> undef,
     reqd  => 1,
     isList => 0
         }),
     stringArg({ name => 'extDbVer',
     descr => 'externaldatabaserelease version of the extDb that this dataset references',
     constraintFunc=> undef,
     reqd  => 1,
     isList => 0
         }),
     stringArg({name => 'organismAbbrev',
	      descr => 'if supplied, use a prefix to use for tuning manager tables',
	      reqd => 0,
	      constraintFunc => undef,
	      isList => 0,
	     }),
    ];

  return $argsDeclaration;
}


# ----------------------------------------------------------
# Documentation
# ----------------------------------------------------------

sub getDocumentation {

  my $description = <<DESCR;
Plugin to load LOD scores for genes and Haplotype Blocks (Haplotype Blocks are regions on a chromosome that are at the same centimorgan distance in the genetic map). This plugin will read a matrix of association LOD scores between genes (as columns) and Hap Blocks (as rows). The Hap Block name is usually the 'Name' field in DoTS.ChromosomeElementFeature table, but this is not enforced.
DESCR

  my $purpose = <<PURPOSE;
Plugin to load LOD scores for genes and Haplotype Blocks (Haplotype Blocks are regions on a chromosome that are at the same centimorgan distance in the genetic map). This plugin will read a matrix of association LOD scores between genes (as columns) and Hap Blocks (as rows). The Hap Block name is usually the 'Name' field in DoTS.ChromosomeElementFeature table, but this is not enforced.
PURPOSE

  my $purposeBrief = <<PURPOSEBRIEF;
Plugin to load LOD scores for genes and Haplotype Blocks.
PURPOSEBRIEF

  my $notes = <<NOTES;
NOTES

  my $tablesAffected = <<AFFECT;
ApiDB.GeneFeatureLodScore
AFFECT

  my $tablesDependedOn = <<TABD;
DoTS.NAFeature, DoTS.GeneFeature, SRes.ExternalDatabaseRelease 
TABD

  my $howToRestart = <<RESTART;
No restart provided. Must undo and reload.
RESTART

  my $failureCases = <<FAIL;
FAIL

  my $documentation = { purpose          => $purpose,
                        purposeBrief     => $purposeBrief,
                        tablesAffected   => $tablesAffected,
                        tablesDependedOn => $tablesDependedOn,
                        howToRestart     => $howToRestart,
                        failureCases     => $failureCases,
                        notes            => $notes
                      };

  return ($documentation);
}

sub new {
  my $class = shift;
  my $self = {};
  bless($self, $class);

  my $documentation = &getDocumentation();

  my $args = &getArgsDeclaration();

  my $configuration = { requiredDbVersion => 3.6,
                        cvsRevision => '$Revision: 45343 $',
                        name => ref($self),
                        argsDeclaration => $args,
                        documentation => $documentation
                      };

  $self->initialize($configuration);

  return $self;
}

sub run {
  my $self = shift;

  my $extDbReleaseId = $self->getExtDbRlsId($self->getArg('extDbName'),
             $self->getArg('extDbVer')) || $self->error("Can't find external_database_release_id for this data");

  my $processed = 1;
  my $header = 1; 
  my (@genes, %geneFeature);

  open(inputFile,$self->getArg('file'));

  while(<inputFile>){
    chomp;
    my @elements = split(/\t/,$_);
    my ($cMorgan);

    if ($header) {
      @genes = @elements[2..(@elements-1)];
      
      foreach my $gene (@genes) {
	  my $naFeatureId =  GUS::Supported::Util::getGeneFeatureId($self, $gene, 0, $self->getArg('organismAbbrev')) ;
          my $geneFeat = GUS::Model::DoTS::GeneFeature->new({'na_feature_id' => $naFeatureId});
          if ($geneFeat->retrieveFromDB) {
            $geneFeature{$gene} = $geneFeat->getNaFeatureId();
          } 
      } 
      undef($header);
      next;
    }

    $cMorgan = $elements[0]."_".$elements[1];
    my $iter = 2;

   print ("Preparing and loading gene association LOD scores for Hap Block $cMorgan ...\n");

    foreach my $gene (@genes) {
      if ($geneFeature{$gene}) {
        my @score = split(/E/i,$elements[$iter]);
        my $geneFeatLodScore = GUS::Model::ApiDB::GeneFeatureLodScore->new({ 
                                'NA_FEATURE_ID' => $geneFeature{$gene},
                                'HAPLOTYPE_BLOCK_NAME' => $cMorgan,
                                'LOD_SCORE_MANT' => $score[0],
                                'LOD_SCORE_EXP' => $score[1],
                                'EXTERNAL_DATABASE_RELEASE_ID' => $extDbReleaseId
                                 });
        $processed++;
        $geneFeatLodScore->submit();
        $self->undefPointerCache(); 
      }
      $iter++;
    }
    print ("Association LOD scores for Hap Block $cMorgan  parsed and loaded...\n");   
  }
  return "\n$processed lines parsed loaded\n"
}


sub undoTables {
  return ('ApiDB.GeneFeatureLodScore');
}

