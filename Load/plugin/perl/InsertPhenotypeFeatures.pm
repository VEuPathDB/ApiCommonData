package ApiCommonData::Load::Plugin::InsertPhenotypeFeatures;
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
  # GUS4_STATUS | Rethink                        | auto   | broken
  # GUS4_STATUS | dots.gene                      | manual | unreviewed
die 'This file has broken or unreviewed GUS4_STATUS rules.  Please remove this line when all are fixed or absent';
#^^^^^^^^^^^^^^^^^^^^^^^^^ End GUS4_STATUS ^^^^^^^^^^^^^^^^^^^^
@ISA = qw(GUS::PluginMgr::Plugin);

use strict;

use DBI;
use Data::Dumper;
use XML::Simple;
use GUS::PluginMgr::Plugin;
use GUS::Model::ApiDB::PhenotypeFeature;
use Data::Dumper;
use GUS::Supported::Util;
use Scalar::Util 'reftype';


sub getArgsDeclaration {
my $argsDeclaration  =
[

     stringArg({ name => 'inputFile',
		 descr => 'XML file that the plugin has to be run on',
		 constraintFunc=> undef,
		 reqd  => 1,
		 isList => 0,
		 mustExist => 1,
	       }),
     stringArg({ name => 'extDbName',
		 descr => 'externaldatabase name',
		 constraintFunc=> undef,
		 reqd  => 1,
		 isList => 0
	       }),
     stringArg({ name => 'extDbVer',
		 descr => 'externaldatabaserelease version',
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


sub getDocumentation {

  my $description = <<NOTES;
NOTES

  my $purpose = <<PURPOSE;
PURPOSE

  my $purposeBrief = <<PURPOSEBRIEF;
PURPOSEBRIEF

  my $syntax = <<SYNTAX;
SYNTAX

  my $notes = <<NOTES;
NOTES

  my $tablesAffected = <<AFFECT;
AFFECT

  my $tablesDependedOn = <<TABD;
TABD

  my $howToRestart = <<RESTART;
RESTART

  my $failureCases = <<FAIL;
FAIL

  my $documentation = {purpose=>$purpose, purposeBrief=>$purposeBrief,tablesAffected=>$tablesAffected,tablesDependedOn=>$tablesDependedOn,howToRestart=>$howToRestart,failureCases=>$failureCases,notes=>$notes};

  return ($documentation);
}



sub new {
  my $class = shift;
  my $self = {};
  bless($self, $class);

  my $documentation = &getDocumentation();

  my $args = &getArgsDeclaration();

  $self->initialize({requiredDbVersion => 3.6,
		     cvsRevision => '$Revision$',
		      name => ref($self),
		     argsDeclaration   => $args,
		     documentation     => $documentation
		    });
  return $self;
}

sub run {
  my $self = shift;

  my $extDbReleaseId = $self->getExtDbRlsId($self->getArg('extDbName'),$self->getArg('extDbVer'))
    || $self->error("Cannot find external_database_release_id for the data source");

  my $file = $self->getArg('inputFile');

  my $conf = $self->parseSimple($file);

  my $rmgms = $conf->{'rmgm'};	#list of rmgms

  $self->insertPhenotypeFeature($rmgms,$extDbReleaseId);

  return "Processed $file.";
}

sub parseSimple{
  my ($self,$file) = @_;

  my $simple = XML::Simple->new();
  my $tree = $simple->XMLin($file, forcearray=>['modification'], SuppressEmpty=>undef);
  return $tree;
}

sub insertPhenotypeFeature {
  my ($self, $rmgms, $extDbReleaseId) = @_;

  my $count = 0; 

  foreach my $rmgm (@$rmgms) {

    my $suc_of_gen_mod = $rmgm->{'success_of_genetic_modification'};
    my $rmgmid = $rmgm->{'rmgmid'};
    my $reference_pubmed = $rmgm->{'reference_pubmed1'};
    my $phenotype_asexual = $rmgm->{'phenotype'}->{'phenotype_asexual'};
    my $phenotype_gametocyte = $rmgm->{'phenotype'}->{'phenotype_gametocyte'};
    my $phenotype_ookinete = $rmgm->{'phenotype'}->{'phenotype_ookinete'};
    my $phenotype_oocyst = $rmgm->{'phenotype'}->{'phenotype_oocyst'};
    my $phenotype_sporozoite = $rmgm->{'phenotype'}->{'phenotype_sporozoite'};
    my $phenotype_liverstage = $rmgm->{'phenotype'}->{'phenotype_liverstage'};

    my $phenotype_remarks = $rmgm->{'phenotype'}->{'phenotype_remarks'};

    $phenotype_remarks =~ s/\n//g;
    $phenotype_remarks =~ s/<(.*?)>//gi;

    my $modifications = $rmgm->{'modifications'}->{'modification'};

      foreach my $modification (@$modifications){
	   my $sourceId = $modification->{'gene_model'};
           my $mod_type = $modification->{'mod_type'};



           my $naFeatureId =  GUS::Supported::Util::getGeneFeatureId($self, $sourceId, 0, $self->getArg('organismAbbrev')) ;
	   if ($naFeatureId){

	       my $phenofeature = GUS::Model::ApiDB::PhenotypeFeature->new({external_database_release_id => $extDbReleaseId,
							       na_feature_id => $naFeatureId,
							       rmgmid => $rmgmid,
							       suc_of_gen_mod => $suc_of_gen_mod,
							       reference_pubmed => $reference_pubmed,
							       phenotype_asexual => $phenotype_asexual,
							       phenotype_gametocyte => $phenotype_gametocyte,
							       phenotype_ookinete => $phenotype_ookinete,
							       phenotype_oocyst => $phenotype_oocyst,
							       phenotype_sporozoite => $phenotype_sporozoite,
							       phenotype_liverstage => $phenotype_liverstage,
							       phenotype_remarks => $phenotype_remarks,
							       mod_type => $mod_type,
							      });
	       $phenofeature->submit();
	       $count++;
	       $self->undefPointerCache() if $count % 1000 == 0;
	   }else {
	         $self->log("WARNING", "No naFeatureId for Source_id '$sourceId'");
	   }
      }
}

  $self->log("Inserted $count features");

}


sub undoTables {
  my ($self) = @_;

  return (
		'ApiDB.PhenotypeFeature'
     );
}

1;

