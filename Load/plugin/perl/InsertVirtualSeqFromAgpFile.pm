package ApiCommonData::Load::Plugin::InsertVirtualSeqFromAgpFile;
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
  # GUS4_STATUS | DeprecatedTables               | auto   | absent
  # GUS4_STATUS | Pathway                        | auto   | absent
  # GUS4_STATUS | DoTS.SequenceVariation         | auto   | absent
  # GUS4_STATUS | RNASeq Junctions               | auto   | absent
  # GUS4_STATUS | Simple Rename                  | auto   | absent
  # GUS4_STATUS | ApiDB Tuning Gene              | auto   | absent
  # GUS4_STATUS | Rethink                        | auto   | absent
  # GUS4_STATUS | dots.gene                      | manual | unreviewed
#^^^^^^^^^^^^^^^^^^^^^^^^^ End GUS4_STATUS ^^^^^^^^^^^^^^^^^^^^

@ISA = qw(GUS::PluginMgr::Plugin);

use strict;
use warnings;

use GUS::PluginMgr::Plugin;

use GUS::Model::DoTS::NASequence;
use GUS::Model::DoTS::ExternalNASequence;
use GUS::Model::SRes::ExternalDatabase;
use GUS::Model::SRes::ExternalDatabaseRelease;
use GUS::Model::DoTS::VirtualSequence;
use GUS::Model::DoTS::SequencePiece;
use GUS::Model::SRes::OntologyTerm;
use GUS::Model::SRes::Taxon;

use Bio::PrimarySeq;
use Bio::Tools::SeqStats;
use GUS::Supported::Util;

sub getArgsDeclaration {
my $argsDeclaration  =
[

fileArg({name => 'agpFile',
         descr => 'file of virtual seq being assembled from parts in agp format',
         constraintFunc=> undef,
         reqd  => 1,
         isList => 0,
         mustExist => 1,
         format=>'Text'
        }),

fileArg({name => 'chromosomeOrderMappingFile',
         descr => 'Tab-delimited file containing source_id,chromosome_number,chromosome_order_number mapping if virtualSeqSOTerm is chromosome',
         constraintFunc=> undef,
         reqd  => 0,
         isList => 0,
         mustExist => 0,
         format=>'Text'
        }),

stringArg({name => 'seqPieceExtDbName',
       descr => 'External database name for sequence piece or part',
       constraintFunc=> undef,
       reqd  => 1,
       isList => 0
      }),

stringArg({name => 'sourceIdPrefix',
       descr => 'Optional String to prepend to the source_id',
       constraintFunc=> undef,
       reqd  => 0,
       isList => 0
      }),

stringArg({name => 'seqPieceExtDbRlsVer',
       descr => 'Version of external database for sequence piece',
       constraintFunc=> undef,
       reqd  => 1,
       isList => 0
      }),

stringArg({name => 'virSeqExtDbName',
       descr => 'External database name for virtual sequence being assembled',
       constraintFunc=> undef,
       reqd  => 1,
       isList => 0
      }),

stringArg({name => 'virSeqExtDbRlsVer',
       descr => 'Version of external database for virtual sequence being assembled',
       constraintFunc=> undef,
       reqd  => 1,
       isList => 0
      }),

stringArg({name => 'virtualSeqSOTerm',
       descr => 'SO term describing the newly built virtual sequences',
       constraintFunc=> undef,
       reqd  => 1,
       isList => 0
      }),
integerArg({name => 'ncbiTaxId',
       descr => 'ncbi_tax_id for the virtual and the components sequences',
       constraintFunc=> undef,
       reqd  => 1,
       isList => 0,
      }),
 integerArg({name => 'spacerNum',
       descr => 'Num Ns inserted between sequence pieces if not provided in file, column 6 if column 5 = N',
       constraintFunc=> undef,
       reqd  => 0,
       isList => 0,
      }),
 stringArg({name => 'soExtDbRlsName',
       descr => 'External Database Release name of Sequence ontology',
       constraintFunc=> undef,
       reqd  => 1,
       isList => 0,
      }),
 integerArg({name => 'retart',
       descr => 'comma delimited list of row_alg_invocation_ids',
       constraintFunc=> undef,
       reqd  => 0,
       isList => 0,
      }),

 booleanArg({  name            =>  'chromosomesInOrder', 
               descr           =>  'if true the chromosomes are in sequential order in agp file',
               reqd            =>  0,
               isList          =>  0
              }),

 booleanArg({  name            =>  'notChromosomes', 
               descr           =>  'if true the virtual sequences are not chromosomes and do not require chromosome name/order numbers',
               reqd            =>  0,
               isList          =>  0
              }),
 stringArg({   name           => 'regexChromosome',
	       descr          => 'The regular expression to pick the chromosome from the source id',
	       reqd           => 0,
	       constraintFunc => undef,
	       isList         => 0 }),
 booleanArg({  name            =>  'allowSplits', 
               descr           =>  'if true the plugin allows splitting a genome piece for use in more than one virtual sequence',
               reqd            =>  0,
               isList          =>  0
              }),

];

return $argsDeclaration;
}


# ----------------------------------------------------------
# Documentation
# ----------------------------------------------------------

sub getDocumentation {

my $description = <<NOTES;
NOTES

my $purpose = <<PURPOSE;
Load virtual sequences from pieces using mapping file with agp format, http://www.ncbi.nlm.nih.gov/projects/genome/guide/Assembly/AGP_Specification.html 
PURPOSE

my $purposeBrief = <<PURPOSEBRIEF;
Load virtual sequences from pieces using agp mapping file
PURPOSEBRIEF

my $syntax = <<SYNTAX;
SYNTAX

my $notes = <<NOTES;
The file:
Tab delimited
cols are 1-object,2-object_beginning,3-object_end,4-part_number,5-component_type(N=gap w/known length,U-gap w/o known length,W=wgs contig,P=predraft,O=other seq,G=whole genome finishing),6-component_id if 5 not N(U) else gap_length,7-component_beg if 5 not N(U) else gap_type (fragment,etc),8-component_end if 5 not N(U) else yes/no gap is beetween adjacent lines,9-orientation(+=forward,-=reverse,0=unknown, na=not applicable) if 5 not N(U) else not used
All object and component distances should be sequential and non-overlapping, all beg <= end
1-based (first base =1 and not 0)
make sure there are not carriage returns in the file, ^M, if so run dos2unix
NOTES

my $tablesAffected = <<AFFECT;
sres.externaldatabase
sres.externaldatabaserelease
dots.sequencepiece
dots.nasequence
AFFECT

my $tablesDependedOn = <<TABD;
sres.OntologyTerm
dots.externalnasequence
TABD

my $howToRestart = <<RESTART;
use restart argument and provide list of alg_invocation_id
RESTART

my $failureCases = <<FAIL;
file badly formatted
file has dos characters which cause unpredictable behavior
sequence pieces not in dots.externalnasequence
db name and version for sequence piece incorrect
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

  my $configuration = {requiredDbVersion => 4.0,
		       cvsRevision => '$Revision$',
		       cvsTag => '$Name$',
		       name => ref($self),
		       revisionNotes => '',
		       argsDeclaration => $args,
		       documentation => $documentation
		      };

  $self->initialize($configuration);

  return $self;
}


sub run {
  my $self = shift;

  my $file = $self->getArg('agpFile');

  die "Do not use 'chromosomeOrderMappingFile' and 'chromosomesInOrder' and 'notChromosomes' and 'regexChromosomes', use only one of them. Use regexChromosomes only if the chromosome is a numerical value. Else use chromosomeOrderMappingFile.\n" if ($self->getArg('chromosomeOrderMappingFile') && $self->getArg('chromosomesInOrder') && $self->getArg('notChromosomes')) && $self->getArg('regexChromosomes');

 $self->validateFileFormat($file);

  my $restart = $self->getArg('retart');

  my $done;

  if($restart){
    my $restartIds = join(",",@$restart);
    $done = $self->restart($restartIds);
    $self->log("Restarting with algorithm invocation IDs: $restartIds");
  }

  my $results = $self->processFile($file,$done);

  my $stmt = "$results dots.VirtualSequence rows inserted\n";

  return $stmt;
}


sub processFile {
  my ($self,$file,$done) = @_;

  my $virAcc;

  my $numVirInserted=0;

  my (%virtual,$refChromosomeOrderMapping,$chromosomeOrder,$chromosome);

  if ($self->getArg('chromosomeOrderMappingFile') && $self->getArg('virtualSeqSOTerm') eq 'chromosome' ){

      my $chromosomeOrderMappingFile = $self->getArg('chromosomeOrderMappingFile') ;

      $refChromosomeOrderMapping=$self->getChromOrderMapping($chromosomeOrderMappingFile);
  }

  open(FILE, "<$file") or die "Couldn't open file '$file':\n";

  while (<FILE>) {
    chomp;

    next if ($_ =~ /^#/ || $_ =~ /^\s*$/);

    my @arr = split(/\t/, $_);

    $virAcc = $arr[0] if (! $virAcc);

    next if ($self->getArg('retart') && $done->{$arr[0]} == 1);

    if ($arr[0] ne $virAcc) {
      $numVirInserted++;

      if ($self->getArg('regexChromosome')){
	  my $regexChromosome = $self->getArg('regexChromosome');
	  if ($regexChromosome && $virAcc =~ /$regexChromosome/) {
	      $chromosome = $1;
	  }
      
  
	  if($chromosome =~ /^\d+$/){
	      $chromosomeOrder = $chromosome;
	  }
      }else{

	  my $chromOrderNumFromFile = $refChromosomeOrderMapping->{$virAcc}->{chrom_order_num} if $refChromosomeOrderMapping->{$virAcc}->{chrom_order_num};

	  my $chromFromFile;
	  if($refChromosomeOrderMapping->{$virAcc}->{chromosome}){
	      $chromFromFile = $refChromosomeOrderMapping->{$virAcc}->{chromosome};
	  }elsif($chromOrderNumFromFile){
	      $chromFromFile = $chromOrderNumFromFile;
	  }
	  $chromosomeOrder= $self->getArg('chromosomesInOrder') ? $numVirInserted : $chromOrderNumFromFile;
	  
	  $chromosome= $self->getArg('chromosomesInOrder') ? $numVirInserted : $chromFromFile;

      }

      die "No chromosome or chromosome order information provided for virtual sequence\n" if ( (!($chromosomeOrder || $self->getArg('notChromosomes')) || !($chromosome || $self->getArg('notChromosomes')) ) && $self->getArg('virtualSeqSOTerm') eq 'chromosome');

      $self->makeVirtualSequence(\%virtual, $virAcc, $chromosomeOrder, $chromosome);

      $self->log("$numVirInserted VirtualSequences rows inserted\n");

      $virAcc = $arr[0];

      %virtual = ();
    }

    $arr[8] =~ s/[na0]// unless $arr[4] =~ /[NU]/;
    #$arr[8] =~ s/\+/1/ unless $arr[4] =~ /[NU]/;
    #$arr[8] =~ s/\-/2/ unless $arr[4] =~ /[NU]/;

    $virtual{$arr[3]}{'virtualBeg'} = $arr[1];
    $virtual{$arr[3]}{'pieceType'} = $arr[4];
    $virtual{$arr[3]}{'gaplength'} = $arr[5] if ($arr[4] =~ /[NU]/);
    $virtual{$arr[3]}{'pieceId'} = $arr[5] if ($arr[4] !~ /[NU]/);
    $virtual{$arr[3]}{'pieceBeg'} = $arr[6] if ($arr[4] !~ /[NU]/);
    $virtual{$arr[3]}{'pieceEnd'} = $arr[7] if ($arr[4] !~ /[NU]/);
    $virtual{$arr[3]}{'strand'} = $arr[8] if ($arr[4] !~ /[NU]/);

  }

  $chromosomeOrder=$self->getArg('chromosomesInOrder') ? $numVirInserted : $refChromosomeOrderMapping->{$virAcc}->{chrom_order_num};
  $chromosome=$refChromosomeOrderMapping->{$virAcc}->{chromosome};
 
  $numVirInserted += $self->makeVirtualSequence(\%virtual, $virAcc, $chromosomeOrder, $chromosome);

  $self->log("$numVirInserted VirtualSequences rows inserted\n");

  close (FILE);

  return $numVirInserted;
}

sub getChromOrderMapping{
  my ($self, $chromosomeOrderMappingFile) = @_;

  my %chromosomeOrderMapping;

  open(FILE, "<$chromosomeOrderMappingFile") or die "Couldn't open file '$chromosomeOrderMappingFile':\n";

  while (<FILE>) {
    chomp;

    next if ($_ =~ /^#/ || $_ =~ /^\s*$/);

    my @arr = split(/\t/, $_);

    $chromosomeOrderMapping{$arr[0]}->{chromosome} = $arr[1]; 
    $chromosomeOrderMapping{$arr[0]}->{chrom_order_num} = $arr[2] if $arr[2];
  }

  return \%chromosomeOrderMapping;

}

sub makeVirtualSequence {
  my ($self, $virtual, $virAcc, $chromosomeOrderNum, $chromosome) = @_;

  my $sourceIdPrefix = $self->getArg('sourceIdPrefix');
  my $sourceId = $sourceIdPrefix ? $sourceIdPrefix . $virAcc : $virAcc;

  my $dbh = $self->getDbHandle();
  $dbh->{'LongReadLen'} = 50_000_000;

  my $virDbRlsId = $self->getVirDbRlsId($self->getArg('virSeqExtDbName'),$self->getArg('virSeqExtDbRlsVer'));
  my $SOTermId = $self->getSOTermId($self->getArg("virtualSeqSOTerm"));
  my $taxonId = $self->getTaxonId($self->getArg('ncbiTaxId'));


  my $virtualSeq;

  if($chromosomeOrderNum){
      $virtualSeq = GUS::Model::DoTS::VirtualSequence->new({source_id => $sourceId, 
                                                           chromosome => $chromosome,
                                                           chromosome_order_num => $chromosomeOrderNum,
                                                           external_database_release_id => $virDbRlsId,
                                                           sequence_version => 1,
                                                           sequence_ontology_id => $SOTermId,
                                                           taxon_id => $taxonId
                                                          });
  }else{
      $virtualSeq = GUS::Model::DoTS::VirtualSequence->new({source_id => $sourceId, 
                                                           external_database_release_id => $virDbRlsId,
                                                           sequence_version => 1,
                                                           sequence_ontology_id => $SOTermId,
                                                           taxon_id => $taxonId
                                                          });
  }
  
  $virtualSeq->retrieveFromDB();

  my $sequence;

  my $pieceDbRlsId = $self->getExtDbRlsId($self->getArg('seqPieceExtDbName'),$self->getArg('seqPieceExtDbRlsVer'));

  my $gapSOId = $self->getSOTermId('gap');

  if ($self->getArg('spacerNum')) {
    $sequence = $self->makeVirWithSpacer($virtualSeq,$virtual,$pieceDbRlsId,$gapSOId);
  }
  else {
    $sequence = $self->makeVir($virtualSeq,$virtual,$pieceDbRlsId,$gapSOId);
  }


  $virtualSeq->setSequence($sequence);

  my $virtualBioperlSeq = Bio::PrimarySeq->new(-seq => $sequence);

  if ($virtualBioperlSeq->seq()) {
      my $seqcount = Bio::Tools::SeqStats->count_monomers($virtualBioperlSeq);

      $virtualSeq->setACount($seqcount->{'A'});
      $virtualSeq->setCCount($seqcount->{'C'});
      $virtualSeq->setGCount($seqcount->{'G'});
      $virtualSeq->setTCount($seqcount->{'T'});
  
  } 
  my $submitted = $virtualSeq->submit();
  $virtualSeq->undefPointerCache();

  return $submitted;
}

sub makeVirWithSpacer {
  my ($self,$virtualSeq,$virtual,$pieceDbRlsId,$gapSOId) = @_;

  my $sequence = "";

  my $spacer = $self->getArg('spacerNum');

  my $totalPieces = scalar (keys %$virtual);

  foreach my $pieceNumber (sort {$a<=>$b} keys %$virtual) {

    my $pieceObj = $self->getPieceObj($virtual,$pieceNumber,$pieceDbRlsId);
    my $start = $virtual->{$pieceNumber}->{'pieceBeg'};
    my $end = $virtual->{$pieceNumber}->{'pieceEnd'};

    my $orderNum = $pieceNumber == 1 ? $pieceNumber : $pieceNumber + 2;

    my $length = length($sequence);

    my $seqPieceObj = $self->makeSequencePiece($virtual->{$pieceNumber}->{'strand'},$orderNum,$start,$end,$length,$pieceObj);

    $virtualSeq->addChild($seqPieceObj);

    my $pieceSeq = $pieceObj->getSubstrFromClob('sequence',$start,($end - $start + 1));


    $pieceSeq = Bio::PrimarySeq->new(-seq => $pieceSeq)->revcom->seq() if $virtual->{$pieceNumber}->{'strand'} eq '-';

    $sequence .= $pieceSeq;

    my $gapObj = $self->getGapObj($spacer,$gapSOId);

    last() if ($totalPieces == $pieceNumber);

    $orderNum = $pieceNumber + 1;

    $length = length($sequence);

    $seqPieceObj = $self->makeSequencePiece('',$orderNum,1,$spacer,$length,$gapObj);

    $virtualSeq->addChild($seqPieceObj);

    $pieceSeq = $pieceObj->getSequence();

    $sequence .= $pieceSeq;
  }

 return $sequence;
}

sub makeVir {
  my ($self,$virtualSeq,$virtual,$pieceDbRlsId,$gapSOId) = @_;

  my $sequence = "";
  my $pieceSeq;

  foreach my $pieceNumber (sort {$a<=>$b} keys %$virtual) {
    my $pieceObj;
    my ($start,$end);

    if ($virtual->{$pieceNumber}->{'pieceType'} =~ /[NU]/){
      my $gapLength = $virtual->{$pieceNumber}->{'gaplength'};
      $pieceObj = $self->getGapObj($virtual->{$pieceNumber}->{'gaplength'},$gapSOId);
      $pieceSeq = $pieceObj->getSequence();
      $start = 1;
      $end = $gapLength;
    }
    else {
      $pieceObj = $self->getPieceObj($virtual,$pieceNumber,$pieceDbRlsId);
      $start = $virtual->{$pieceNumber}->{'pieceBeg'};
      $end = $virtual->{$pieceNumber}->{'pieceEnd'};
      $pieceSeq = $pieceObj->getSubstrFromClob('sequence',$start,($end - $start + 1));
      $pieceSeq = Bio::PrimarySeq->new(-seq => $pieceSeq)->revcom->seq() if $virtual->{$pieceNumber}->{'strand'} eq '-';    }

    my $length = length($sequence);

    my $seqPieceObj = $self->makeSequencePiece($virtual->{$pieceNumber}->{'strand'},$pieceNumber,$start,$end,$length,$pieceObj);

    $virtualSeq->addChild($seqPieceObj);

    $sequence .= $pieceSeq;
  }

  return $sequence;
}

sub getPieceObj {
  my ($self,$virtual,$pieceNumber,$pieceDbRlsId) = @_;

  my $source_id = $virtual->{$pieceNumber}->{'pieceId'};

  my $NASeq =  GUS::Model::DoTS::NASequence->new({'source_id' => $source_id,
							    'external_database_release_id' => $pieceDbRlsId});

  unless ($NASeq->retrieveFromDB()) {
    die "sequence not in Dots.ExternalNASequence: $source_id";
  }

  return $NASeq;
}

sub getGapObj {
  my ($self,$length,$SOId) = @_;

  my $sequence .= "N" x $length;

  my $gap = GUS::Model::DoTS::ExternalNASequence->new({'sequence_ontology_id' => $SOId, 
						       'length' => $length,
						       'sequence_version' => 1 });

  if (! $gap->retrieveFromDB()) {
    $gap ->setSequence($sequence);
    $gap->submit();
  }

  return $gap;
}

sub  makeSequencePiece {
  my ($self, $orientation,$pieceNumber,$start,$end,$offset,$pieceObj) = @_;

  my $pieceId = $pieceObj->getId();

  my $seqPiece = GUS::Model::DoTS::SequencePiece->new({sequence_order => $pieceNumber,
						       strand_orientation => $orientation,
						       start_position => $start,
						       end_position => $end,
						       distance_from_left => $offset,
						       piece_na_sequence_id => $pieceId});

  return $seqPiece;
}

sub getVirDbRlsId {
  my ($self, $dbName, $dbVer) = @_;

  my $sql = "select external_database_id from sres.externaldatabase where lower(name) like '" . lc($dbName) ."'";
  my $sth = $self->prepareAndExecute($sql);
  my ($dbId) = $sth->fetchrow_array();
  $sth->finish();

  unless ($dbId){
    my $newDatabase = GUS::Model::SRes::ExternalDatabase->new({name => $dbName});
    $newDatabase->submit();
    $dbId = $newDatabase->getId();
  }

  $sql = "select external_database_release_id from sres.externaldatabaserelease where external_database_id = $dbId and version = '".$dbVer."'";
  $sth = $self->prepareAndExecute($sql);
  my ($dbRlsId) = $sth->fetchrow_array();

  unless ($dbRlsId){
    my $newDatabaseRelease = GUS::Model::SRes::ExternalDatabaseRelease->new({external_database_id => $dbId,version => $dbVer});
    $newDatabaseRelease->submit();
    $dbRlsId = $newDatabaseRelease->getId();
  }

  $dbRlsId or die "Can't make virtual seq db release id for: $dbName, $dbVer";

  return $dbRlsId;
}


sub getSOTermId {
  my($self,$SOTerm) = @_;

  my $soExtDbRlsName = $self->getArg('soExtDbRlsName');

  my $soExtDbRlsVer =  GUS::Supported::Util::getExtDbRlsVerFromExtDbRlsName($self, $soExtDbRlsName);

  my $soExternalDatabaseSpec=$soExtDbRlsName."|".$soExtDbRlsVer;

  my $soDbRlsId = 
      $self->getExtDbRlsId($soExternalDatabaseSpec);

  my $SO = GUS::Model::SRes::OntologyTerm->new({'name' => $SOTerm,'external_database_release_id' => $soDbRlsId});

  unless($SO->retrieveFromDB()) {
    die "SO Term $SOTerm not found in sres.OntologyTerm.name.\n";
  }

  my $SOId = $SO->getOntologyTermId();

  return $SOId;
}

sub getTaxonId {
  my ($self,$ncbiTaxId) = @_;
  my $taxon = GUS::Model::SRes::Taxon->new({ncbi_tax_id => $ncbiTaxId});

  unless ($taxon->retrieveFromDB()) {
    die "$ncbiTaxId not found in sres.taxon.ncbi_tax_id\n";
  }

  my $taxonId = $taxon->getId();

  return $taxonId;
}

sub validateFileFormat {
  my ($self, $file) = @_;

  $self->log("Validating $file, agp file format\n");

  open(FILE,$file) or die "Can't open $file for validation";

  my $acc = "";
  my $num;
  my (%testFragmentIds, @checkItems);

  while(<FILE>){
    next if ($_ =~ /#/);
    chomp;
    my @arr = split(/\t/,$_);

    if ($arr[0] ne $acc){
      $acc = $arr[0];
      $num = 0;
    }
    $num++;
    my $arrSize = @arr;

    $testFragmentIds{$arr[5]} += 1;

    if ($arr[4] =~ /[NU]/ && $self->getArg('spacerNum')) {die "You have asked for insertion of gaps when there are already gaps in the file which is not allowed\n"};
    if ($num != $arr[3]){die "Check agp file, $arr[0], pieces should be in order and start with 1 for each virtual sequence\n";}
    if ($arr[1] !~ /\d+/ || $arr[1] <= 0 || $arr[2] !~ /\d+/  || $arr[2] <= 0  || $arr[3] !~ /\d+/  || $arr[3] <= 0 ){ die "Check agp file format, columns 2,3 and 4 must be positive number";}
    if ($arr[4] =~ /N/ && ($arr[5] !~ /\d+/ || $arr[5] <= 0)) { die "Check agp file format, column 6 must be a positive number when a line represents a gap";}
    if ($arr[4] !~ /[NU]/ && ($arr[6] !~ /\d+/ || $arr[6] <= 0 || $arr[7] !~ /\d+/ || $arr[7] <= 0 )) { die "Check agp file format, columns 7 and 8 must be a positive numbers when a line represents a sequence piece";}
    if ($arr[4] !~ /[NUWPOGDF]/) {die "Check file format, the fifth column must be N,U,W,P,O,G,F controlled designations of component types";}
    if ($arr[4] !~ /[NU]/ && ($arr[8] !~ /[+-0na]/)){die "Check agp file format lines with sequence pieces, not gaps, must have a 9th column that is +,-,0, or na for orientation/n";}
    if ($arr[4] !~ /[NU]/ && ($arr[1] > $arr[2] || $arr[6] > $arr[7] || ($arr[2] - $arr[1] != $arr[7] - $arr[6]))) { die "Check data,col 3 - col 2 should equal to col 8 - col 7";}

  }

  foreach my $k (sort keys %testFragmentIds) {
    push (@checkItems, $k) if ($testFragmentIds{$k} > 1 && $k !~ /^\d+/);
  }
  if (scalar(@checkItems) > 0) { 
    $self->log("WARNING .... Check agp file for splitted genome piece(s)".join (", ", @checkItems)."\n");
    die "Check agp file for ".join (", ", @checkItems).", one single fragment can only be assembled to one position\n" unless $self->getArg('allowSplits');
  }

  $self->log("File format validated\n");
}

sub restart{
  my ($self, $restartIds) = @_;
  my %done;

  my $sourceIdPrefix = $self->getArg('sourceIdPrefix');

  my $sql = "SELECT source_id FROM DoTS.VirtualSequence WHERE row_alg_invocation_id IN ($restartIds)";

  my $qh = $self->getQueryHandle();
  my $sth = $qh->prepareAndExecute($sql);

  while(my ($id) = $sth->fetchrow_array()){
    $id = $sourceIdPrefix . $id if($id);
    $done{$id}=1;
  }
  $sth->finish();

  return \%done;
}




sub undoTables {
  my ($self) = @_;

  return ('DoTS.SequencePiece',
	  'DoTS.NASequence',
	 );
}

return 1;

__DATA__
#Example data this plugin parses:

# ORGANISM: Giardia lamblia ATCC50803
# TAX_ID:184922 
# ASSEMBLY NAME:GL2
# ASSEMBLY DATE: 01-September-2005
# GENOME CENTER: MARBILAB
# DESCRIPTION:Linkage information for 92 scaffolds from Arachne WGS assembly
SC_577  1       1104    1       W       AACB02000219.1  1       1104    +
SC_577  1105    1204    2       N       100     fragment        yes
SC_577  1205    2021    3       W       AACB02000299.1  1       817     +
SC_577  2022    2121    4       N       100     fragment        yes
SC_577  2122    286031  5       W       AACB02000007.1  1       283910  +
SC_577  286032  286131  6       N       100     fragment        yes
SC_577  286132  347373  7       W       AACB02000055.1  1       61242   +
SC_577  347374  347473  8       N       100     fragment        yes
SC_577  347474  348996  9       W       AACB02000146.1  1       1523    +
SC_577  348997  349096  10      N       100     fragment        yes
SC_577  349097  436945  11      W       AACB02000037.1  1       87849   +
SC_577  436946  437045  12      N       100     fragment        yes
SC_577  437046  440367  13      W       AACB02000096.1  1       3322    +
SC_577  440368  440467  14      N       100     fragment        yes
SC_577  440468  468633  15      W       AACB02000073.1  1       28166   +
SC_577  468634  468733  16      N       100     fragment        yes
SC_577  468734  549655  17      W       AACB02000042.1  1       80922   +
