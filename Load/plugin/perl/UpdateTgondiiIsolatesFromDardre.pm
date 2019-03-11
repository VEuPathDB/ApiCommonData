package ApiCommonData::Load::Plugin::UpdateTgondiiIsolatesFromDardre;
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
  # GUS4_STATUS | dots.gene                      | manual | reviewed
#^^^^^^^^^^^^^^^^^^^^^^^^^ End GUS4_STATUS ^^^^^^^^^^^^^^^^^^^^
@ISA = qw(GUS::PluginMgr::Plugin);

use strict;
use warnings;

use GUS::PluginMgr::Plugin;
use GUS::Model::DoTS::IsolateSource;
use GUS::Model::DoTS::IsolateFeature;
use GUS::Model::DoTS::NASequence;
use GUS::Model::DoTS::NAFeature;

use FileHandle;
use lib "$ENV{GUS_HOME}/lib/perl";

my $argsDeclaration =
  [
   fileArg({ name           => 'inputFile',
	     descr          => 'The input tab-delimited file',
	     reqd           => 1,
	     mustExist      => 1,
	     format         => 'tab delimited file',
	     constraintFunc => undef,
	     isList         => 0,
	   }),

   stringArg({ name           => 'extDbRlsSpec',
	       descr          => 'the ExternalDatabaseRelease specification of the isolates to be updated',
	       reqd           => 1,
	       constraintFunc => undef,
	       isList         => 0,
	     }),


  ];

my $purpose = <<PURPOSE;
To update isolates loaded from Genbank files with additional information provided by the Dardre group.
PURPOSE


my $purposeBrief = <<PURPOSE_BRIEF;
To update isolates loaded from Genbank file with additional information from Dardre group.
PURPOSE_BRIEF

my $notes = <<NOTES;

NOTES

my $tablesAffected = [['DoTS.IsolateSource', 'Updates strain, specific_host, country fields for isolates present in input file'],['DoTS.IsolateFeature', 'Updates gene_type fields for isolates present in input file']];


my $tablesDependedOn = [];

my $howToRestart = <<RESTART;
No restart.
RESTART

my $failureCases = <<FAIL_CASES;
None known.
FAIL_CASES

my $documentation =
  { purpose          => $purpose,
    purposeBrief     => $purposeBrief,
    notes            => $notes,
    tablesAffected   => $tablesAffected,
    tablesDependedOn => $tablesDependedOn,
    howToRestart     => $howToRestart,
    failureCases     => $failureCases
  };

sub new {

  my ($class) = @_;

  my $self = {};
  bless($self, $class);

  $self->initialize({ requiredDbVersion => 4.0,
		      cvsRevision       => '$Revision: 29209 $',
		      name              => ref($self),
		      argsDeclaration   => $argsDeclaration,
		      documentation     => $documentation
		    });

  return $self;
}

sub run {
  my ($self) = @_;

  $self->log("Parsing isolates file\n");
  my $isolates = $self->getIsolates($self->getArg('inputFile'));

  $self->log("Update isolate source and features\n");
  my $msg = $self->updateIsolates($isolates);

  return $msg;
}

sub getIsolates{
  my ($self,$file) = @_;
  my %isolates;

  my $count = 0;

  my $extDbRls = $self->getExtDbRlsId($self->getArg('extDbRlsSpec')) or die "Couldn't find external database in db\n";

  open(FILE, "$file") or die ("Can't open file $file: $!\n");

  my $accession = '';
  while(<FILE>){
    chomp;
    
    my($strain,$host,$country,$geneType,@cols) = split(/\t/,$_);
    
    for(my $i=2;$i<=$#cols;$i=$i+3){
      $accession .= "'$cols[$i]',";
      push(@{$isolates{$cols[$i]}},$strain,$host,$country,$geneType);
    }
    
   

    
  }
  
  close(FILE);
  $accession =~ s/,$//;


      my $sql = <<EOSQL;

      SELECT ens.na_sequence_id, ens.source_id,
         f.na_feature_id, f.subclass_view
      FROM DoTS.NAFeature f,
      DoTS.ExternalNASequence ens
      WHERE f.external_database_release_id = $extDbRls
      AND f.subclass_view IN ('IsolateSource')
      AND f.na_sequence_id = ens.na_sequence_id
      AND ens.source_id IN ($accession) ORDER BY f.subclass_view

EOSQL
      
  my $stmt = $self->prepareAndExecute($sql);    
      while (my ($sequenceId, $sourceId,$featureId, $subclassView) = $stmt->fetchrow_array()) {
	
	push(@{$isolates{$sourceId}},$sequenceId,$featureId);

      }
  
my $sql2 = <<EOSQL;

      SELECT ens.na_sequence_id, ens.source_id,
         f.na_feature_id, f.subclass_view
      FROM DoTS.NAFeature f,
      DoTS.ExternalNASequence ens
      WHERE f.external_database_release_id = $extDbRls
      AND f.subclass_view IN ('IsolateFeature')
      AND f.na_sequence_id = ens.na_sequence_id
      AND ens.source_id IN ($accession) ORDER BY f.subclass_view

EOSQL
      
  my $stmt2 = $self->prepareAndExecute($sql2);    
      while (my ($sequenceId, $sourceId,$featureId, $subclassView) = $stmt2->fetchrow_array()) {
	
	push(@{$isolates{$sourceId}},$sequenceId,$featureId);

      }

  return \%isolates;
}


sub updateIsolates{
  my ($self, $isolates) = @_;


  
  my $sourceCount = 0;
  my $featCount = 0;

  foreach my $accession (keys %{$isolates}){

         my($strain,$host,$country,$geneType,$sequenceId,$sourceId,$seqId2,$featId) = @{$isolates->{$accession}};
	 

	 if($sourceId){
	     my $updateSource = GUS::Model::DoTS::IsolateSource->new({
						      na_feature_id => $sourceId,
						      });
	     unless($updateSource->retrieveFromDB()){
		 print $updateSource->toString();
		 $self->error("Could not retrieve feature from database\n");
	     }
	     $updateSource->set('strain',$strain);
	     $updateSource->set('specific_host',$host);
	     $updateSource->set('country',$country);
	
	     

	     $updateSource->submit();
	     $sourceCount++;
	 }
	  
	 if($featId){
	     my $updateFeature = GUS::Model::DoTS::IsolateFeature->new({
						      na_feature_id => $featId,
						  });
          unless($updateFeature->retrieveFromDB()){
	      print $updateFeature->toString();
	      $self->error("Could not retrieve feature from database\n");
	  }

	     $updateFeature->set('gene_type',$geneType);


	     $updateFeature->submit();
	     $featCount++;

	 }


       }

  
  my $msg = "Updated $sourceCount IsolateSource and $featCount IsolateFeature\n";
  return $msg;

}


