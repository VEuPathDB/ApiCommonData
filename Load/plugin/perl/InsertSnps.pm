package ApiCommonData::Load::Plugin::InsertSnps;
@ISA = qw(GUS::PluginMgr::Plugin);

use strict;

use GUS::PluginMgr::Plugin;
use GUS::Model::DoTS::ExternalNASequence;
use GUS::Model::SRes::SequenceOntology;
use GUS::Model::DoTS::SeqVariation;
use GUS::Model::DoTS::NALocation;


$| = 1;

# ---------------------------------------------------------------------------
# Load Arguments
# ---------------------------------------------------------------------------

sub getArgumentsDeclaration{
  my $argsDeclaration =
    [
     stringArg({name => 'snpExternalDatabaseName',
		descr => 'sres.externaldatabase.name for SNP source',
		constraintFunc => undef,
		reqd => 1,
		isList => 0
	       }),
     stringArg({name => 'snpExternalDatabaseVersion',
		descr => 'sres.externaldatabaserelease.version for this SNP source',
		constraintFunc => undef,
		reqd => 1,
		isList => 0
	       }),
     stringArg({name => 'naExternalDatabaseName',
		descr => 'sres.externaldatabase.name for the genome sequences',
		constraintFunc => undef,
		reqd => 1,
		isList => 0
	       }),
     stringArg({name => 'naExternalDatabaseVersion',
		descr => 'sres.externaldatabaserelease.version for the genome sequences',
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
     stringArg({name => 'snpFile',
		descr => 'tab delimited file containing the SNP data',
		constraintFunc => undef,
		reqd => 1,
		isList => 0,
		mustExist => 1,
		format => 'GFF, Ex:995313  Stanford        SNP     3093368 3093369 .       .       .       SNP TGG_995313_Contig28_138 ; Allele RH:C ; Allele ME49:- ; Allele VEG:-'
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
    ];
  return $argsDeclaration;
}

# ----------------------------------------------------------------------
# Documentation
# ----------------------------------------------------------------------

sub getDocumentation {
  my $purposeBrief = "Inserts SNP data into DoTS.SeqVariation and the location into DoTS.NALocation";

  my $purpose = "Inserts SNP information from a gff formatted file into into DoTS.SeqVariation and the location into DoTS.NALocation.";

  my $tablesAffected = [['DoTS::SeqVariation', 'One or more rows inserted per SNP, row number equal to strain number'],['DoTS::NALocation', 'A single row inserted per SNP']];

  my $tablesDependedOn = [['DoTS::ExternalNASequence', 'Genome sequence containing the SNP'], ['SRes::SequenceOntology',  'SequenceOntology term equal to SNP required']];

  my $howToRestart = "Use restart option and last processed row number from STDOUT file.";

  my $failureCases = "";

  my $notes = "";

  my $documentation = {purpose=>$purpose, purposeBrief=>$purposeBrief, tablesAffected=>$tablesAffected, tablesDependedOn=>$tablesDependedOn, howToRestart=>$howToRestart, failureCases=>$failureCases,notes=>$notes};

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
                     documentation => $documentation});

  return $self;
}

# ----------------------------------------------------------------------
# run method to do the work
# ----------------------------------------------------------------------

sub run {
  my ($self) = @_;

  $self->logAlgInvocationId();
  $self->logCommit();
  $self->logArgs();

  my ($linesProcessed) = $self->processSnpFile();

  my $file = $self->getArg('snpFile');

  my $resultDescrip = "$linesProcessed lines of SNP file $file processed";

  $self->setResultDescr($resultDescrip);
  $self->logData($resultDescrip);
}

sub processSnpFile{
  my ($self) = @_;

  my $lineNum = $self->getArg('restart') ? $self->getArg('restart') : 0;

  $self->{'soId'} = $self->getSoId();

  $self->{'snpExtDbRlsId'} = $self->getExtDbRlsId($self->getArg('snpExternalDatabaseName'),$self->getArg('snpExternalDatabaseVersion'));

  $self->{'naExtDbRlsId'} = $self->getExtDbRlsId($self->getArg('naExternalDatabaseName'),$self->getArg('naExternalDatabaseVersion'));

  my $file = $self->getArg('snpFile');

  my $num = 0;

  open (SNP, $file);

  while(<SNP>){
    chomp;

    $num++;

    next if ($self->getArg('restart') && $num <= $lineNum);

    my @line = split(/\t/,$_);

    my $seqVarRows = $self->getSeqVars(\@line);

    foreach my $seqVar (@$seqVarRows) {

      my $naSeq = $self->getNaSeq(\@line);

      $seqVar->setParent($naSeq);

      my $naLoc = $self->getNaLoc(\@line);

      $seqVar->addChild($naLoc);

      $seqVar->submit();
    }

    $self->undefPointerCache();

    $lineNum++;

    $self->logData("processed file line number = $lineNum\n");
  }

  return $lineNum;

}

sub getSeqVars {
  my ($self,$line) = @_;

  my $extDbRlsId = $self->{'snpExtDbRlsId'};

  my $soId = $self->{'soId'};

  my @data = split (/;/, $line->[8]);

  my $sourceId = $data[0];

  my $organism = $self->getArg('organism');

  $sourceId =~ s/SNP\s(\S+)\s/$1/;

  my $start = $line->[3];

  my $end = $line->[4];

  my $ref = $self->getArg('reference');

  my $standard = $end = $start + 1 ? 'insertion' : 'substitute';

  my @seqVarRows;

  foreach my $element (@data) {
    if ($element =~ /Allele\s(\w+):([\w\-]+)/) {

      my $strain = $1;
      my $base = $2;

      $standard = $end = $start + 1 ? 'insertion' : 'substitute';
      $standard = 'reference' if lc($ref) eq lc($strain);
      $standard = 'deletion' if ($standard eq 'substitute' && $base =~ /-/);

      my $seqvar =  GUS::Model::DoTS::SeqVariation->new({'source_id'=>$sourceId,'external_database_release_id'=>$extDbRlsId,'name'=>'SNP','standard_name'=>$standard,'sequence_ontology_id'=>$soId,'strain'=>$strain,'allele'=>$base,'organism'=>$organism});

      $seqvar->retrieveFromDB();

      push (@seqVarRows, $seqvar);
    }
  }

    return \@seqVarRows;

}

sub getSoId {
  my ($self) = @_;

  my $so = GUS::Model::SRes::SequenceOntology->new({'term_name'=>'SNP'});

  if (!$so->retrieveFromDB()) {
    $self->error("No row has been added for term_name = SNP in the sres.sequenceontology table\n");
  }

  my $soId = $so->getId();

  return $soId;

}

sub getNaSeq {
   my ($self,$line) = @_;

   my $sourceId = $line->[0];

   my $extDbRlsId = $self->{'naExtDbRlsId'};

   my $naSeq = GUS::Model::DoTS::ExternalNASequence->new({'source_id'=>$sourceId,'external_database_release_id'=>$extDbRlsId});

   $naSeq->retrieveFromDB() || $self->error(" $sourceId does not exist in the database with database release = $extDbRlsId\n");

   return $naSeq;

}

sub getNaLoc {
  my ($self,$line) = @_;

  my $start = $line->[3];

  my $end = $line->[4];

  my $locType = $end == $start + 1 ? 'insertion_site' : 'modified_base_site';

  my $naLoc = GUS::Model::DoTS::NALocation->new({'start_min'=>$start,'start_max'=>$start,'end_min'=>$end,'end_max'=>$end,'location_type'=>$locType});

  return $naLoc;

}


1;
