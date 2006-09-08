package ApiCommonData::Load::Plugin::InsertAlleleFeature;
@ISA = qw(GUS::PluginMgr::Plugin);

use strict;

use GUS::PluginMgr::Plugin;
use GUS::Model::SRes::SequenceOntology;
use GUS::Model::DoTS::AlleleFeature;
use GUS::Model::DoTS::NALocation;


# ---------------------------------------------------------------------------
# Load Arguments
# ---------------------------------------------------------------------------

sub getArgumentsDeclaration{
  my $argsDeclaration =
    [
     stringArg({name => 'featExtDbRlsSpec',
		descr => 'what is the external database name and version for the allele feature data',
		constraintFunc => undef,
		reqd => 1,
		isList => 0
	       }),

     stringArg({name => 'naExtDbRlsSpec',
		descr => 'what is the external database name and version for the genome sequences',
		constraintFunc => undef,
		reqd => 1,
		isList => 0
	       }),

     stringArg({name => 'seqTable',
		descr => 'where do we find the nucleotide sequences',
		constraintFunc => undef,
		reqd => 1,
		isList => 0
	       }),

     stringArg({name => 'organism',
		descr => 'Genus and species, example T. gondii',
		constraintFunc=> undef,
		reqd  => 1,
		isList => 0
	       }),

     stringArg({name => 'featFile',
		descr => 'tab delimited file containing the SNP data',
		constraintFunc => undef,
		reqd => 1,
		isList => 0,
		mustExist => 1,
		format => 'GFF like: Ia	Sibley	sequence_variant	749	749	.	+	.	GeneticMarker AK3'
	       }),

     stringArg({name => 'reference',
		descr => 'Strain or individual used as reference for all indels and substitutions',
		constraintFunc=> undef,
		reqd  => 1,
		isList => 0,
	       }),

     integerArg({name => 'restart',
		descr => 'for restarting use number from last processed row number in STDOUT',
	        constraintFunc => undef,
	        reqd => 0,
	        isList => 0
	    }),

     stringArg({name => 'ontologyTerm',
		descr => 'Ontology term describing the type of genetic variant being added to the database',
		constraintFunc=> undef,
		reqd  => 1,
		isList => 0,
	       }),

     stringArg({name => 'featureType',
		descr => 'The type of allele feature that is being loaded, ex: Genetic Marker',
		constraintFunc=> undef,
		reqd  => 0,
		isList => 0,
	       }),
    ];
  return $argsDeclaration;
}

# ---------------------------------------------------------------------
# Documentation
# ---------------------------------------------------------------------

sub getDocumentation {
  my $purposeBrief = "Inserts allele feature data into DoTS.AlleleFeature and the location into DoTS.NALocation. This plugin does not handle allele features with DoTS.SeqVariation children, although it could easily be modified to do so.";

  my $purpose = "Inserts data from a gff formatted file into into DoTS.AlleleFeature and the location into DoTS.NALocation.";

  my $tablesAffected = [['DoTS::AlleleFeature', 'One or more rows inserted per allele feature, row number equal to strain number'],['DoTS::NALocation', 'A single row inserted per DoTS.AlleleFeature row']];

  my $tablesDependedOn = [['SRes::SequenceOntology',  'SequenceOntology term for data type being entered'],['DoTS.NASequence','One of the views on this table will be specified as the one holding the sequences the features map to.']];

  my $howToRestart = "Use restart option and last processed row number from STDOUT file.";

  my $failureCases = "";

  my $notes = "";

  my $documentation = { purpose=>$purpose,
			purposeBrief=>$purposeBrief,
			tablesAffected=>$tablesAffected,
			tablesDependedOn=>$tablesDependedOn,
			howToRestart=>$howToRestart,
			failureCases=>$failureCases,
			notes=>$notes
		      };

  return $documentation;
}

# ----------------------------------------------------------------------
# create and initalize new plugin instance.
# ----------------------------------------------------------------------

sub new {
  my ($class) = @_;
  my $self = {};
  bless($self,$class);

  my $documentation = &getDocumentation();
  my $argumentDeclaration = &getArgumentsDeclaration();


  $self->initialize({requiredDbVersion => 3.5,
		     cvsRevision => '$Revision$',
                     name => ref($self),
                     revisionNotes => '',
                     argsDeclaration => $argumentDeclaration,
                     documentation => $documentation
		    });

  return $self;
}


# ----------------------------------------------------------------------
# run method to do the work
# ----------------------------------------------------------------------

sub run {
  my ($self) = @_;

  my $dbh = $self->getDbHandle();
  $dbh->{'LongReadLen'} = 10_000_000;

  $dbh = $self->getQueryHandle();
  $dbh->{'LongReadLen'} = 10_000_000;

  my ($linesProcessed) = $self->processSnpFile();

  my $file = $self->getArg('featFile');

  return "$linesProcessed lines of file $file processed\n";


}

sub processSnpFile{
  my ($self) = @_;

  my $lineNum = $self->getArg('restart') ? $self->getArg('restart') : 0;

  $self->{'termName'} = $self->getArg('ontologyTerm');
  $self->{'soId'} = $self->getSoId($self->{'termName'});
  die "The term $self->{'termName'} was not found in the Sequence Ontology.\n" unless $self->{'soId'};

  $self->{'featureType'} = $self->getArg('featureType');
  $self->{'organism'} = $self->getArg('organism');
  $self->{'reference'} = $self->getArg('reference');

  $self->{'featExtDbRlsId'} = $self->getExtDbRlsId($self->getArg('featExtDbRlsSpec'));

  $self->{'naExtDbRlsId'} = $self->getExtDbRlsId($self->getArg('naExtDbRlsSpec'));

  my $file = $self->getArg('featFile');

  my $num = 0;

  open (FILE, $file);

  while(<FILE>){
    chomp;

    $num++;

    next if ($self->getArg('restart') && $num <= $lineNum);

    my @line = split(/\t/,$_);

    my $alleleFeatRows = $self->getAlleleFeats(\@line);

    foreach my $alleleFeat (@$alleleFeatRows) {

      my $naSeq = $self->getNaSeq(\@line);

      $alleleFeat->setParent($naSeq);

      my $naLoc = $self->getNaLoc(\@line);

      $alleleFeat->addChild($naLoc);

      $alleleFeat->submit();
    }

    $self->undefPointerCache();

    $lineNum++;

    if ($lineNum%10 == 0){
      $self->log("processed $lineNum lines from $file.\n");
    }
  }

  return $lineNum;

}


sub getAlleleFeats {
  my ($self,$line) = @_;
  my $extDbRlsId = $self->{'featExtDbRlsId'};
  my $soId = $self->{'soId'};
  my $organism = $self->{'organism'};
  my $ref = $self->{'reference'};
  my $name = $self->{'featureType'};

  my @data = split (/;/, $line->[8]);

  my $sourceId = $data[0];

  if ($sourceId =~ /\w+\s(\w+)/){
    $sourceId = $1;
  }

  my @alleleFeatRows;
  my $description = "Reference Strain $organism $ref";

  my $alleleFeat =  GUS::Model::DoTS::AlleleFeature->new({
				   'source_id'=>$sourceId,
				   'external_database_release_id'=>$extDbRlsId,
				   'name'=>$name,
				   'sequence_ontology_id'=>$soId,
				   'description'=> $description,
				   });

    $alleleFeat->retrieveFromDB();

    push (@alleleFeatRows, $alleleFeat);


  return \@alleleFeatRows;

}


sub getSoId {
  my ($self, $termName) = @_;

  my $so = GUS::Model::SRes::SequenceOntology->new({'term_name'=>$termName});

  if (!$so->retrieveFromDB()) {
    $self->error("No row has been added for term_name = $termName in the sres.sequenceontology table\n");
  }

  my $soId = $so->getId();

  return $soId;

}


sub getNaSeq {
  my ($self,$line) = @_;

  my $sourceId = $line->[0];

  my $extDbRlsId = $self->{'naExtDbRlsId'};

  my ($seqTable) = $self->getArg("seqTable");
  $seqTable = "GUS::Model::$seqTable";
  eval "require $seqTable";

  my $naSeq = $seqTable->new({'source_id'=>$sourceId,'external_database_release_id'=>$extDbRlsId});

  $naSeq->retrieveFromDB() || $self->error(" $sourceId does not exist in $seqTable with database release = $extDbRlsId\n");

  return $naSeq;
}


sub getNaLoc {
  my ($self,$line) = @_;
  my $locType = $self->{'termName'};

  my $start = $line->[3];
  my $end = $line->[4];

  my $naLoc = GUS::Model::DoTS::NALocation->new({'start_min'=>$start,
						 'start_max'=>$start,
						 'end_min'=>$end,
						 'end_max'=>$end,
						 'location_type'=>$locType,
						});

  return $naLoc;

}


sub undoTables {
  my ($self) = @_;

  return ('DoTS.NALocation',
	  'DoTS.AlleleFeature',
	 );
}

1;
