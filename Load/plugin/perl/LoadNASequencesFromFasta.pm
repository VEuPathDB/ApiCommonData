package ApiCommonData::Load::Plugin::LoadNASequencesFromFasta;
#vvvvvvvvvvvvvvvvvvvvvvvvv GUS4_STATUS vvvvvvvvvvvvvvvvvvvvvvvvv
  # GUS4_STATUS | SRes.OntologyTerm              | auto   | absent
  # GUS4_STATUS | SRes.SequenceOntology          | auto   | fixed
  # GUS4_STATUS | Study.OntologyEntry            | auto   | absent
  # GUS4_STATUS | SRes.GOTerm                    | auto   | absent
  # GUS4_STATUS | Dots.RNAFeatureExon            | auto   | absent
  # GUS4_STATUS | RAD.SageTag                    | auto   | absent
  # GUS4_STATUS | RAD.Analysis                   | auto   | absent
  # GUS4_STATUS | ApiDB.Profile                  | auto   | absent
  # GUS4_STATUS | Study.Study                    | auto   | absent
  # GUS4_STATUS | Dots.Isolate                   | auto   | absent
  # GUS4_STATUS | DeprecatedTables               | auto   | absent # leaving Sres.Contact
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
use GUS::PluginMgr::Plugin;
use File::Basename;
use GUS::Model::DoTS::ExternalNASequence;
use GUS::Model::SRes::Taxon;
use GUS::Model::SRes::OntologyTerm;
use Bio::PrimarySeq;
use Bio::Tools::SeqStats;



my $argsDeclaration =[];
my $purposeBrief = 'Insert NA sequences from a FASTA file.';

my $purpose = <<PLUGIN_PURPOSE;
Insert or update sequences from a FASTA.  A set of regular expressions provided on the command line extract from the definition lines of the input sequences various information to stuff into the database.
PLUGIN_PURPOSE

my $tablesAffected =
  [ ['DoTS::ExternalNASequence', 'one row per EST'],['SRES::Contact','one row per library'],['SRES::Library','one row per library']
  ];

my $tablesDependedOn =
  [['SRES::Taxon','taxon_id required for library and externalnasequence tables'],['SRes::OntologyTerm',  'OntologyTerm term for sequence type']
  ];

  my $howToRestart = "Get the total number of ESTs processed from log file, second column, that number plus one for startAt argument"; 

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


sub new() {
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

  $self->{external_database_release_id} = $self->getExtDbRlsId($self->getArg('externalDatabaseName'), $self->getArg('externalDatabaseVersion'));

  $self->log("loading sequences with external database release id $self->{external_database_release_id}");

  $self->fetchSequenceOntologyId();

  $self->processFile();

  my $finalCount = $self->{totalCount} + $self->{skippedCount};

  my $res = "Run finished: $finalCount Sequences entered ";
  return $res;


}

sub processFile{
  my ($self) = @_;
  
  my $file = $self->getArg('fastaFile');
  
  $self->logVerbose("loading sequences from $file\n");
  if ($file =~ /gz$/) {
    open(F, "gunzip -c $file |") || die "Can't open $file for reading";
  } else {
    open(F,"$file") || die "Can't open $file for reading";
  }
  
  my $source_id;
  my $taxon_id;
  my $secondary_id;
  my $seq;
  my $seqLength;
  my $desc;

  #my $sql = $self->getArg('checkSQL') ? $self->getArg('checkSQL') : "select na_sequence_id from dots.externalnasequence where source_id = ? and external_database_release_id = $self->{external_database_release_id}";
  
 # my $checkStmt = $self->getAlgInvocation()->getQueryHandle()->prepare($sql);
  
  while (my $line = <F>) {
    if ($line =~ /^\>/) {                ##have a defline....need to process!
        
      $self->undefPointerCache();

      if ($seq) {
        $self->process($source_id,$secondary_id,$taxon_id,$seq,$seqLength,$desc);
      }
      
      ##now get the ids etc for this defline...
      $secondary_id = ""; $desc = "";##in case can't parse out of this defline...
      ($source_id, $secondary_id, $taxon_id, $desc) = split('|',$line);
      
      ##reset the sequence..
      $seq = "";
    }
    else {
      $seq .= $_;
      $seq =~ s/\s//g;
      $seqLength = length($seq);
    }
    
  }
  
  $self->process($source_id, $secondary_id, $taxon_id, $seq, $seqLength, $desc) if ($source_id && $seq);
}

sub process {
  my($self,$source_id,$secondary_id,$taxon_id,$seq,$seqLength,$description) = @_;

  my $nas = $self->createNewExternalSequence($source_id,$secondary_id,$seq,$taxon_id,$description);


  $nas->submit();

  $nas->undefPointerCache();

  $self->{totalCount}++;

  my $total = $self->{totalCount} + $self->{skippedCount};

  $self->log("processed sourceId: $source_id  and total processed: $total");
}

sub createNewExternalSequence {
  my($self, $source_id,$secondary_id,$seq,$taxon_id,$description) = @_;

  my $nas = GUS::Model::DoTS::ExternalNASequence->
    new({'external_database_release_id' => $self->{external_database_release_id},
	 'source_id' => $source_id,
	 'sequence_ontology_id' => $self->{sequenceOntologyId} });

  my $taxonObj = GUS::Model::SRes::Taxon->new({ ncbi_tax_id => $taxon_id });

  unless ($taxonObj->retrieveFromDB()) {
    $self->log("No Row in SRes::Taxon for ncbi tax id $taxon_id");
    $taxonObj = undef;
  }
  $nas->setParent($taxonObj) if (defined $taxonObj);

  if ($secondary_id && $nas->isValidAttribute('secondary_identifier')) {
    $nas->setSecondaryIdentifier($secondary_id);
  }

  if ($description) { 
    $description =~ s/\"//g; $description =~ s/\'//g;
    $nas->set('description',substr($description,0,255));
  }

  $nas->setSequence($seq);

  $self->getMonomerCount($nas,$seq);

  return $nas;
}

sub getMonomerCount{
  my ($self, $aas, $seq)=@_;
  my $monomersHash;
  my $countA = 0;
  my $countT = 0;
  my $countC = 0;
  my $countG = 0;
  my $countOther = 0;

  $seq =~ s/-//g;

  my $seqobj = Bio::PrimarySeq->new(-seq=>$seq,
				    -alphabet=>'dna');

  my $seqStats  =  Bio::Tools::SeqStats->new(-seq=>$seqobj);

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
      $countOther = $$monomersHash{$base};
    }
  }

  $aas->setACount($countA);
  $aas->setTCount($countT);
  $aas->setCCount($countC);
  $aas->setGCount($countG);
  $aas->setOtherCount($countOther);

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
               'ApiDB.Reference16S',
               'DoTS.ExternalNASequence',
             );

}

1;
