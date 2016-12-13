package ApiCommonData::Load::Plugin::LoadNASequencesFromFasta;

@ISA = qw(GUS::PluginMgr::Plugin);
use strict;
use GUS::PluginMgr::Plugin;
use File::Basename;
use GUS::Model::DoTS::ExternalNASequence;
use GUS::Model::SRes::Taxon;
use GUS::Model::SRes::OntologyTerm;
use Bio::PrimarySeq;
use Bio::SeqIO;
use Bio::Seq;
use Bio::Tools::SeqStats;

use Data::Dumper;

my $argsDeclaration =[];
my $purposeBrief = 'Insert NA sequences from a FASTA file.';

my $purpose = <<PLUGIN_PURPOSE;
Insert or update sequences from a FASTA.
PLUGIN_PURPOSE

my $tablesAffected =
  [ ['DoTS::ExternalNASequence', 'one row per Sequence']
  ];

my $tablesDependedOn =
  [['SRES::Taxon','taxon_id for externalnasequence table'],['SRes::OntologyTerm',  'OntologyTerm term for sequence type']
  ];

  my $howToRestart = ""; 

  my $failureCases = <<PLUGIN_FAILURE_CASES;
PLUGIN_FAILURE_CASES

my $notes = <<PLUGIN_NOTES;

PLUGIN_NOTES


  my $documentation = { purpose=>$purpose,
                        purposeBrief=>$purposeBrief,
                        tablesAffected=>$tablesAffected,
                        tablesDependedOn=>$tablesDependedOn,
                        howToRestart=>$howToRestart,
                        failureCases=>$failureCases,
                        notes=>$notes
                      };

my $argsDeclaration =
[

 fileArg({   name            => 'fastaFile',
	     descr           => 'The name of the input fasta file',
	     reqd            => 1,
	     constraintFunc  => undef,
             mustExist       => 1,
             format          =>"",
             isList          => 0 }),

 stringArg({ name            => 'externalDatabaseName',
	     descr           => 'The name of the ExternalDatabase from which the input sequences have come',
	     reqd            => 1,
	     constraintFunc  => undef,
	     isList          => 0 }),

 stringArg({ name            => 'externalDatabaseVersion',
	     descr           => 'The version of the ExternalDatabaseRelease from whith the input sequences have come',
	     reqd            => 1,
	     constraintFunc  => undef,
	     isList          => 0 }),

 stringArg({name => 'SOTermName',
            descr => 'The extDbRlsName of the Sequence Ontology to use',
            reqd => 1,
            constraintFunc => undef,
            isList => 0
           }),

 stringArg({name => 'SOExtDbRlsSpec',
            descr => 'The extDbRlsName of the Sequence Ontology to use',
            reqd => 1,
            constraintFunc => undef,
            isList => 0
           }),

];


sub new {
  my ($class) = @_;
  my $self = {};
  bless($self,$class);

  $self->initialize({requiredDbVersion => 4.0,
		     cvsRevision => '$Revision$', # cvs fills this in!
		     name => ref($self),
		     argsDeclaration   => $argsDeclaration,
		     documentation     => $documentation
		    });
  return $self;
}


$| = 1;

sub run {
  my $self  = shift;

  $self->{totalCount} = 0;
  $self->{skippedCount} = 0;

  $self->cacheTaxonNodes();
  $self->{external_database_release_id} = $self->getExtDbRlsId($self->getArg('externalDatabaseName'), $self->getArg('externalDatabaseVersion'));

  $self->log("loading sequences with external database release id $self->{external_database_release_id}");

  $self->fetchSequenceOntologyId();

  

  $self->processFile();

  my $finalCount = $self->{totalCount} + $self->{skippedCount};

  my $res = "Run finished: $finalCount Sequences entered ";
  return $res;


}

sub cacheTaxonNodes{
  my ($self) = @_;
  
  my $sql = "select distinct t.ncbi_tax_id, t.taxon_id
                     from sres.taxon t";
  
  my $dbh = $self->getQueryHandle();
  my $sh = $dbh->prepare($sql);
  $sh->execute();
  while(my ($ncbi_taxon_id, $sres_taxon_id) = $sh->fetchrow_array()) {
    $self->{_taxon_nodes}->{$ncbi_taxon_id}=$sres_taxon_id;
  }
  $sh->finish();

        
}

sub processFile{
  my ($self) = @_;
  
  my $file = $self->getArg('fastaFile');
  
  $self->logVerbose("loading sequences from $file\n");

  my $seq_count = 1;
  my $seq_io = Bio::SeqIO->new(-file => $file,
                                                      -format=>'Fasta');
  
  while(my $seq_object = $seq_io->next_seq) {
    $seq_count++;
    my $def_line = $seq_object->primary_id;
    my ($source_id, $secondary_id, $taxon_id, $description);
    $secondary_id = ""; $description = "";##in case can't parse out of this defline...
    ($source_id, $secondary_id, $taxon_id, $description) = split(/\|/,$def_line); 
    $self->process($source_id, $secondary_id, $taxon_id, $seq_object, $description);
  }
}

sub process {
  my($self,$source_id,$secondary_id,$taxon_id,$seq_object,$description) = @_;
  
  my $nas = $self->createNewExternalSequence($source_id,$secondary_id,$seq_object,$taxon_id,$description);

  $nas->submit();

  $nas->undefPointerCache();

  $self->{totalCount}++;

  my $total = $self->{totalCount} + $self->{skippedCount};

  if ($total % 10000 == 0){
    $self->log("total processed: $total");
  }
}

sub createNewExternalSequence {
  my($self, $source_id,$secondary_id,$seq_object,$taxon_id,$description) = @_;

  my $nas = GUS::Model::DoTS::ExternalNASequence->
    new({'external_database_release_id' => $self->{external_database_release_id},
	 'source_id' => $source_id,
         'sequence_version' => 1,
	 'sequence_ontology_id' => $self->{sequenceOntologyId} });

  my $taxonObj = undef;

  $taxonObj = GUS::Model::SRes::Taxon->new({ taxon_id =>  $self->{_taxon_nodes}->{$taxon_id} }) if defined $self->{_taxon_nodes}->{$taxon_id};

  if (defined $taxonObj) {
    $nas->setParent($taxonObj) ;
  }
  else {
    $self->log("Taxon ID : $taxon_id for Sequence Source ID : $source_id not found in Sres.taxon");
  }
  if ($secondary_id && $nas->isValidAttribute('secondary_identifier')) {
    $nas->setSecondaryIdentifier($secondary_id);
  }

  if ($description) { 
    $description =~ s/\"//g; $description =~ s/\'//g;
    $nas->set('description',substr($description,0,255));
  }
  my $seq = $seq_object->seq();

  $nas->setSequence($seq);

  $self->getMonomerCount($nas,$seq_object);

  return $nas;

}

sub getMonomerCount{
  my ($self, $nas, $seq_object)=@_;
  my $monomersHash;
  my $countA = 0;
  my $countT = 0;
  my $countC = 0;
  my $countG = 0;
  my $countOther = 0;

  my $seqStats  =  Bio::Tools::SeqStats->new(-seq=>$seq_object);

  $monomersHash = $seqStats->count_monomers();
  foreach my $base (keys %$monomersHash) {
    if ($base eq 'A'){
      $countA = $$monomersHash{$base};
    }
    elsif ($base eq 'T'){
      $countT = $$monomersHash{$base};
    }
    elsif ($base eq 'C'){
      $countC = $$monomersHash{$base};
    }
    elsif ($base eq 'G'){
      $countG = $$monomersHash{$base};
    }
    else{
      $countOther = $countOther + $$monomersHash{$base};
    }
  }

  $nas->setACount($countA);
  $nas->setTCount($countT);
  $nas->setCCount($countC);
  $nas->setGCount($countG);
  $nas->setOtherCount($countOther);

  return;
}

sub fetchSequenceOntologyId {
  my ($self) = @_;


  my $name = $self->getArg('SOTermName');
  my $extDbRlsSpec = $self->getArg('SOExtDbRlsSpec');
  my $extDbRlsId = $self->getExtDbRlsId($extDbRlsSpec);

  my $SOTerm = GUS::Model::SRes::OntologyTerm->new({'name' => $name ,
                                                    external_database_release_id => $extDbRlsId
                                                   });

  $SOTerm->retrieveFromDB;

  $self->{sequenceOntologyId} = $SOTerm->getId();

  print STDERR ("SO ID:   ********** $self->{sequenceOntologyId} \n");

  $self->{sequenceOntologyId}
    || $self->userError("Can't find SO term '$name' in database");

}

sub undoTables {
  my ($self) = @_;
  return (
               'DoTS.ExternalNASequence',
             );

}

1;
