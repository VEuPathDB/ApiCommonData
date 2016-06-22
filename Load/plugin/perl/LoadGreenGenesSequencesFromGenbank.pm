package ApiCommonData::Load::Plugin::LoadGreenGenesSequencesFromGenbank;
@ISA = qw(GUS::PluginMgr::Plugin);

use strict;

use lib "$ENV{GUS_HOME}/lib/perl";

use Bio::SeqIO;

use GUS::PluginMgr::Plugin;
use GUS::Model::DoTS::ExternalNASequence;
use GUS::Model::SRes::Taxon;
use GUS::Model::SRes::OntologyTerm;

use File::Basename;
use Data::Dumper;

#use lib "$ENV{GUS_HOME}/lib/perl/ApiCommonWebsite/Model";
#use ApiCommonShared::Model::pcbiPubmed;

my $purposeBrief = <<PURPOSEBRIEF;
Insert GenBank sequenece data from a greengenes assignment file. 
PURPOSEBRIEF

my $purpose = <<PURPOSE;
Insert GenBank sequence data from a greengenes assignment file. 
PURPOSE

my $tablesAffected = [
  ['DoTS.ExternalNASequence',     'One row inserted per isolate .ProtocolAppNode row'] 
];

my $tablesDependedOn = [
  ['SRes.Taxon', 'Get the ncbi_taxon_id for each metadata']
];

my $howToRestart = "There is currently no restart method.";

my $failureCases = "There are no know failure cases.";

my $notes = <<PLUGIN_NOTES;
Input File is a typical GenBank file, e.g. GenBank accession AF527841
#MetaData  is inside the /source block, e.g. strain, genotype, country, clone, lat-lon...
PLUGIN_NOTES

my $documentation = { purpose          => $purpose,
                      purposeBrief     => $purposeBrief,
                      tablesAffected   => $tablesAffected,
                      tablesDependedOn => $tablesDependedOn,
                      howToRestart     => $howToRestart,
                      failureCases     => $failureCases,
                      notes            => $notes
                    };

my $argsDeclaration = 
  [
    stringArg({name           => 'extDbName',
               descr          => 'the external database name to tag the data with.',
               reqd           => 1,
               constraintFunc => undef,
               isList         => 0,
             }),
    stringArg({name           => 'extDbRlsVer',
               descr          => 'the version of the external database to tag the data with.',
               reqd           => 1,
               constraintFunc => undef,
               isList         => 0,
             }),
    fileArg({  name           => 'inputFile',
               descr          => 'file containing the data',
               constraintFunc => undef,
               reqd           => 1,
               mustExist      => 1,
               isList         => 0,
               format         =>'Tab-delimited.'
             }), 
   ];

sub new {
  my ($class) = @_;
  my $self = {};
  bless($self,$class); 

  $self->initialize({ requiredDbVersion => 4.0,
                      cvsRevision => '$Revision$', # cvs fills this in!
                      name => ref($self),
                      argsDeclaration => $argsDeclaration,
                      documentation => $documentation
                   });
  return $self;
}

sub run {

  my ($self) = @_;
  my $dbiDb = $self->getDb();
  $dbiDb->setMaximumNumberOfObjects(1000000);

  my $extDbRlsId = $self->getExtDbRlsId($self->getArg('extDbName'), $self->getArg('extDbRlsVer'));
  my $inputFile = $self->getArg('inputFile');
  my ($junk,$inputDir,$junk2) = fileparse($inputFile);
  my $gb_dir = $inputDir."/gb";
  $gb_dir=~s/\/+/\//g;
  my $gb_file_basename = $gb_dir."/output";
 
  mkdir($gb_dir) unless (-d $inputDir."/gb");
  my $id_map_hash = $self->parseInputFile($inputFile, $gb_file_basename);
  my $genbank_ids = $id_map_hash->{Genbank};
  my ($nodeHash, $termHash) = $self->readGenBankFile($gb_dir, $extDbRlsId);

   my $count = $self->loadSequences($nodeHash,$genbank_ids, $extDbRlsId);

   my $msg = "$count sequence records have been loaded.";
   $self->log("$msg \n");
   return $msg;
}

sub parseInputFile {
  my ($self, $inputFile,$gb_file) =@_;
  open(GGFILE, "<$inputFile");
  my $inputHash ={};
  my $gb_ids = {};
  <GGFILE>;
  my $count = 1;
  while(my $line = <GGFILE>){
    $line=~s/\n|\r//g;
    my ($source_id, $seq_source, $seq_source_id) = split( /\t/, $line);
     if ($seq_source=~/genbank/i) {

       $gb_ids->{$seq_source_id} =1;
       next unless ((scalar(keys (%$gb_ids))) % 10000 == 0);
       my $id_list = join(',',keys(%$gb_ids));
       my $cmd = "wgetFromGenbank --output $gb_file"."_"."$count".".gb  --id_list $id_list/";
       system($cmd);
       if ($? == -1) {
         print "failed to execute: $!\n";
       }
       elsif ($? & 127) {
         printf "child died with signal %d, %s coredump\n",
           ($? & 127),  ($? & 128) ? 'with' : 'without';
       }
       else {
         printf "child exited with value %d\n", $? >> 8;
       }
       $gb_ids = {};
       $count = $count+1;
     }

    $inputHash->{$seq_source}->{$seq_source_id}->{source_id}=$source_id;
  }
  my $id_list = join(',',keys(%$gb_ids));
  my $cmd = "wgetFromGenbank --output $gb_file"."_"."$count".".gb  --id_list $id_list";
  system($cmd);
  if ($? == -1) {
    print "failed to execute: $!\n";
  }
  elsif ($? & 127) {
    printf "child died with signal %d, %s coredump\n",
      ($? & 127),  ($? & 128) ? 'with' : 'without';
  }
  else {
    printf "child exited with value %d\n", $? >> 8;
  }
  return $inputHash;
}

sub readGenBankFile {

  my ($self, $gbDir, $extDbRlsId) = @_;

  my %termHash;  # list of distinct source modifiers
  my %nodeHash;  # isolate => { desc => desc; seq => seq; terms => { key => value } }
  
  opendir(my $gb_dir_handle, $gbDir) || die "Can't open dir $gbDir: $!";
  while (my $file = readdir $gb_dir_handle) {
    my $inputFile = "$gbDir"."/"."$file";

    next unless -f $inputFile;
    my $seq_count = 1;
    my $seq_io = Bio::SeqIO->new(-file => $inputFile);

    while(my $seq = $seq_io->next_seq) {
      $seq_count++;
      my $source_id = $seq->accession_number;
      my $desc = $seq->desc; 
   

      if ($seq->molecule =~/^prt$/i) {
        next;
      }


      $nodeHash{$source_id}{desc} = $desc;
      $nodeHash{$source_id}{seq}  = $seq->seq;

      # process source modifiers, extract ncbi_taxon_id
      foreach my $feat ($seq->get_SeqFeatures) {

        my $primary_tag = $feat->primary_tag;
        next unless $primary_tag =~ /source/i;
        foreach my $tag ($feat->get_all_tags) {
          next unless $tag =~ /db_xref/i;

          foreach my $value ($feat->get_tag_values($tag)) {
            next unless $value =~ /taxon:/i;
            my $ncbi_taxon_id = $value;
            $ncbi_taxon_id =~ s/^taxon://i;

            $nodeHash{source_id}{ncbi_taxon_id}=$ncbi_taxon_id;
          } # end foreach value
          
        } # end foreach tag

      } # end foreach feat

      $seq_io->close;
    }# end while seq
  }#end while file
  closedir $gb_dir_handle;
    
  return (\%nodeHash);
}

sub loadSequences {

  my($self, $nodeHash, $source_ids, $extDbRlsId) = @_;

  my $count = 0;

  my $ontologyObj = GUS::Model::SRes::OntologyTerm->new({ name => 'rRNA_16S' });
  $self->error("cannot find ontology term 'rRNA_16S'") unless $ontologyObj->retrieveFromDB;
  print STDERR scalar keys %$nodeHash;
  print STDERR " elements in node hash\n";
  exit;
  while (my ($seq_source_id, $hash) = each %$nodeHash) {
    my $seq = $hash->{seq};
    my $source_id = $source_ids->{$seq_source_id};
    my $extNASeq = $self->buildSequence($nodeHash->{$seq_source_id}->{seq}, $source_id, $extDbRlsId);
    
    my $ncbi_taxon_id = $hash->{ncbi_taxon_id};
    my $taxonObj = GUS::Model::SRes::Taxon->new({ ncbi_tax_id => $ncbi_taxon_id });
    
    if($taxonObj->retrieveFromDB()) {
      $extNASeq->setParent($taxonObj);
    }
    else {
      $self->log("No Row in SRes::Taxon for ncbi tax id $ncbi_taxon_id");
    }
    
    $extNASeq->submit;
    $self->undefPointerCache() if $count++ % 500 == 0;
  }

  return $count;
}

sub buildSequence {
  my ($self, $seq, $source_id, $extDbRlsId) = @_;

  my $extNASeq = GUS::Model::DoTS::ExternalNASequence->new();

  $extNASeq->setExternalDatabaseReleaseId($extDbRlsId);
  $extNASeq->setSequence($seq);
  $extNASeq->setSourceId($source_id);
  $extNASeq->setSequenceVersion(1);

  return $extNASeq;
}

sub undoTables {
  my ($self) = @_;
  return ( 
               'DoTS.ExternalNASequence',
             );

}

1;

