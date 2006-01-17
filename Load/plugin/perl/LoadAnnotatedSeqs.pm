package ApiComplexa::DataLoad::Plugin::LoadAnnotatedSeqs;

@ISA = qw(GUS::PluginMgr::Plugin);

use strict;

use XML::Simple;
use Data::Dumper;
use DBI;
use Digest::MD5;
use CBIL::Util::Disp;

use Bio::SeqIO;
use Bio::SeqFeature::Tools::Unflattener;
use Bio::Tools::SeqStats;
use Bio::SeqFeature::Generic;
use Bio::Location::Fuzzy;

use GUS::PluginMgr::Plugin;
use ApiComplexa::DataLoad::BioperlMapParser;
use ApiComplexa::DataLoad::BioperlFeatureMapper;

#GENERAL USAGE TABLES
use GUS::Model::SRes::ExternalDatabase;
use GUS::Model::SRes::ExternalDatabaseRelease;
use GUS::Model::SRes::Reference;

#USED IN LOADING NASEQUENCE
use GUS::Model::SRes::TaxonName;
use GUS::Model::SRes::SequenceOntology;
use GUS::Model::DoTS::SequenceType;
use GUS::Model::DoTS::ExternalNASequence;
use GUS::Model::DoTS::NAEntry;
use GUS::Model::DoTS::SecondaryAccs;
use GUS::Model::DoTS::NALocation;
use GUS::Model::DoTS::NASequenceRef;
use GUS::Model::DoTS::Keyword;
use GUS::Model::DoTS::NAComment;


#FEATURE VIEWS THAT MAY BE CALLED IN THE MAP
use GUS::Model::DoTS::Organelle;
use GUS::Model::DoTS::NAFeature;
use GUS::Model::DoTS::DNARegulatory;
use GUS::Model::DoTS::DNAStructure;
use GUS::Model::DoTS::STS;
use GUS::Model::DoTS::GeneFeature;
use GUS::Model::DoTS::RNAType;
use GUS::Model::DoTS::Repeats;
use GUS::Model::DoTS::Miscellaneous;
use GUS::Model::DoTS::Immunoglobulin;
use GUS::Model::DoTS::ProteinFeature;
use GUS::Model::DoTS::SeqVariation;
use GUS::Model::DoTS::RNAStructure;
use GUS::Model::DoTS::Source;
use GUS::Model::DoTS::Transcript;
use GUS::Model::DoTS::ExonFeature;

#USED BY TRANSCRIPT FEATURES TO LOAD THE TRANSLATED PROTEIN SEQ
use GUS::Model::DoTS::TranslatedAAFeature;
use GUS::Model::DoTS::TranslatedAASequence;

#TABLES AND VIEWS USED IN SPECIAL CASES
use GUS::Model::DoTS::NAGene;
use GUS::Model::DoTS::NAProtein;
use GUS::Model::DoTS::NAPrimaryTranscript;
use GUS::Model::SRes::DbRef;
use GUS::Model::DoTS::NAFeatureComment;
use GUS::Model::DoTS::NASequenceOrganelle;
use GUS::Model::DoTS::NASequenceKeyword;
use GUS::Model::DoTS::NAFeatureNAGene;
use GUS::Model::DoTS::NAFeatureNAPT;
use GUS::Model::DoTS::NAFeatureNAProtein;
use GUS::Model::DoTS::DbRefNAFeature;




#######################################################
#Note, this version is crap, it is a sketch of fucntionality
#implemented for a specific release of crypto-db
#to be re-written, wait for the good one.
#######################################################
####    STILL TO DO    ####
#
# change restart procedures to file matching and not point checking. 
# need to make the mappers into real objects
# make performance enhancements noted inline in this application
# Move all lookup functions to a set cache objects loaded at start of run
#

#FROM MY NOTES
# need chromosome in na sequence, not just source.
# 
#
#
#
#
#
#

#steve's requests
#- used camelCaps for arg names instead of underscores... we're trying to standardize on this
#- use $self-> consistently for method calls... otherwise we get runtime errs.
#- shortened run method to make it fit on one screen
#- add --unflatten arg... that way we don't hard code what formats are used  (actually, make it a flag, we DO know what formats use rich seqs, etc.  And the unflattener is ONLY for GNEBANK and EMBL.  it says so itself.
#- use FeatureMap object for each <feature> tag
#- improved error msg if bioperl parser fails (inlude the affected vars)
#- improved restart test logic, moved it into a subroutine (not written yet!)
#- moved unflattening into a subroutine 
#- introduced hash to hold special case handlers... this makes future plugging them in easier
#- we need to handle the case of multiple tag values better... should be controlled by xml file
#- lose incorrect and unnec. getDbRelId (hard coding of "unknown" is not a good idea)
#- handle failures from making Feature (eg, db xref not found)
#optimizations (in general reduce RDBMS traffic):
#- load db xrefs into memory (not done yet)
#- load genes and proteins into memory (not done yet)
#- cache taxon_ids (not done yet)
#questions
#- we probably need to use Gene rather than NAGene
#- probably should put Protein and Gene in a separate plugin.
#handling SequenceTypes
#- we need a mapping file as input to map from input types to SO ids.
#handling dbxrefs
#  - by default, use name from input as db name
#  - by default, use "unknown" as version
#  - take optional --defaultDbxrefVersion on command line
#  - take optional --dbxrefMapFile on command line
#  - the map file maps from input name to GUS name and (optionally) version
#  - when a name is first encountered in input, read all its ids into memory
# - if a name is not found in GUS or mapping filem, error

############################################################ 
# Application Context
############################################################

sub new {
   my $class = shift;
   my $self = {};
   bless($self, $class);
   
      my $documentation = &getDocumentation();
      
      my $args = &getArgsDeclaration();
      
      my $configuration = {requiredDbVersion => 3.5,
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



##############################################################
#Cache Objects
##############################################################
sub setContext{
  my $self = shift;
 
  $self->{'formats'} = {'genbank', 'embl', 'tigr'};
  $self->{'genbank'} = {'rich' => 1, 'hier' => 1, 'annot'=> 1};
  $self->{'embl'} = {'rich' => 1, 'hier' => 1, 'annot'=> 1};
  $self->{'tigr'} = {'rich' => 1, 'hier' => 1, 'annot'=> 1};

  $self->{'sequences'} = {};
  $self->{'features'} = {};

        #build your SOId cache
        #build your dbXRef cache
        #build your tax_id cache  (why? its only pulled once)
          #if $self->getArg('restart_file') { restartCachei(getArg('restart_file')); }  build your gene and protein? cache

  my $myCache = loadFeatureLog();

  $self->log("total items in restart cache: $myCache \n");
}

sub loadFeatureLog {
  my $self = shift;

  my $seqCach=0;
  my $fetCach=0;
  open(MYLOG, "<$self->getArg('fail_dir')/las.log");
    while (my $entry = <MYLOG>)   {
    my ($type, $value) = split(/\:/,$entry);   
      $self->{$type}->{$value} = {'1'};
         if ($type="Seq") { $seqCach++; }
         else { $fetCach++; }
    }

  #$self->log("Lines in sequence cache:$seqCach\n");
  #$self->log("Lines in feature cache:$fetCach\n");
  
return ($seqCach + $fetCach);
}


###############################################################
#Main Routine
##############################################################

sub run{
   my $self = shift;

   my ($seqCt, $featCt);
   my $args = $self->getArgs();
   my $format = $self->getArg('file_format');
   $self->setContext();
   $self->startUpLog();

#-----------------------------------------------------------
# Load your Bioperl to Gus map object
#-----------------------------------------------------------
   my $mapper = new ApiComplexa::DataLoad::BioperlMapParser->parseMap($self->getArg('map_xml')) || die "not a valid map file";

   my $in = new Bio::SeqIO(-format=>$format, -file=>$self->getArg('data_file'));

   my $unflattener = Bio::SeqFeature::Tools::Unflattener->new;
   
   #process each seq in the BioSeq Object
   while (my $bp_seq_in = $in->next_seq() ) {          
      my $accession = $bp_seq_in->accession_number();
      next if ($self->seqDonePreviously($bp_seq_in));
      my $gus_na_seq = $self->makeSequence($bp_seq_in, $format);
         eval { $gus_na_seq->submit(); };
            if ($@) {
               $self->handleSeqFailure($bp_seq_in, $@) if ($@);
             next;
             }
            else {
                $self->{'Seq:'}->{$accession} = {'1'};
                $self->log("Sequence:$accession\n"); 
                $seqCt++;
            }
       my  $gusSeqId = $gus_na_seq->getId();  

      #If hierarchical, create unflattened features for this seq
      my $out = Bio::SeqIO->new(-format=>'asciitree');
      if ($self->{$format}->{'hier'} == 1) {
         $unflattener->unflatten_seq(-seq=>$bp_seq_in,-use_magic=>1);
         $out->write_seq($bp_seq_in);}

      foreach my $feat_tree ($bp_seq_in->get_SeqFeatures()) {    
         my $gus_seq_feat = $self->makeFeature($feat_tree, $mapper, $gusSeqId);
              my $cksum = $self->checksumDigest($feat_tree);
              next if ($self->featDonePreviously($cksum));
                     eval { $gus_seq_feat->submit(); };
                      if ($@) {
                        $self->handleFeatFailure($feat_tree, $@);
                        next;
                      }
                      else {
                        $self->{'Feat:'}->{$cksum} = {'1'};
                        $self->log("Feature:$cksum\n"); 
                        $featCt++;
            }
         $self->undefPointerCache();
      }
      $self->log("$accession Processing Complete!\n");
      $self->undefPointerCache();
   }
  $self->dumpLog();
  my $filename = $self->getArgs('data_file');
  $self->setResultDescr("Processed: $filename : $format \n\t Seqs Inserted: $seqCt \n\t Feats Inserted: $featCt");
}

#####################################################################
#Sub-routines
#####################################################################

# ----------------------------------------------------------
# Build your sequence 
# ----------------------------------------------------------
sub makeSequence {
   my ($self, $bp_seq, $format) = @_;

   my $dbRlsId = $self->getExtDbRlsId($self->getArg('extDbName'),$self->getArg('extDbRlsVer'));
   my $gus_na_seq = $self->makeNASequence($bp_seq, $dbRlsId);
   my $gus_naentry = $self->makeNAEntry($bp_seq);
   my @secAccs = $bp_seq->get_secondary_accessions();

   foreach my $secAcc (@secAccs) {
      my $gus_secaccs = $self->makeSecAccs($bp_seq,$secAcc,$dbRlsId);
      $gus_naentry->addChild($gus_secaccs);
   }

   if ($self->{$format}->{'rich'} == 1) {  #if rich, get annotations
       my $anno_collection = $bp_seq->annotation;
         #Annotations we haven't used yet
         #   SEGMENT      segment             SimpleValue e.g. "1 of 2"
         #   ORIGIN       origin              SimpleValue e.g. "X Chromosome."
         #   INV          date_changed        SimpleValue e.g. "08-JUL-1994"
            my @references = $anno_collection->get_Annotations('reference');
            foreach my $reference (@references) {
               my $gus_ref_link = $self->makeReference($reference);
               $gus_na_seq->addChild($gus_ref_link);
             }
            my @comments = $anno_collection->get_Annotations('comment');
            foreach my $comment (@comments) {
#why did this stop working?  Suddenly it is throwing hash refs. will work this out once the rest of this is tested
               #my $gus_cmnt = $self->makeComment($comment);
               #$gus_na_seq->addChild($gus_cmnt);
             }
            my @keywords = $anno_collection->get_Annotations('keyword');
            foreach my $keyword (@keywords) {
              # my $gus_key_link = $self->makeKeyword($keyword);
              # $gus_na_seq->addChild($gus_key_link);
             }

             #ADD ANNOTATIONS TO NA ENTRY
                      #here is where we will add chromosome into NAEntry
     }

   $gus_na_seq->addChild($gus_naentry);

   return $gus_na_seq;
}


# ----------------------------------------------------------
# Make your Primary Sequence
sub makeNASequence {
   my ($self, $bp_seq, $dbRlsId) = @_;
      
   my $taxId = $self->getTaxonId($bp_seq);
   #my $seqtype =  getSeqType($bp_seq_in->molecule());
   my $seqType = getSeqType($self->getArg('seq_type'));  #COMPLETE HACK, DO THIS WITH MAPPING OF NAME TO MOLECULE

   my $gus_na_seq = GUS::Model::DoTS::ExternalNASequence->new();
   my $seqcount = Bio::Tools::SeqStats->count_monomers($bp_seq);
      $gus_na_seq->setSourceId($bp_seq->accession_number());
      $gus_na_seq->setExternalDatabaseReleaseId($dbRlsId);
      $gus_na_seq->setSequenceTypeId($seqType);
      $gus_na_seq->setTaxonId($taxId);
      $gus_na_seq->setName($bp_seq->primary_id());
      $gus_na_seq->setDescription($bp_seq->desc());
      $gus_na_seq->setSequence($bp_seq->seq());
      $gus_na_seq->setSequenceVersion($bp_seq->seq_version());
      $gus_na_seq->setACount(%$seqcount->{'A'});
      $gus_na_seq->setCCount(%$seqcount->{'C'});
      $gus_na_seq->setGCount(%$seqcount->{'G'});
      $gus_na_seq->setTCount(%$seqcount->{'T'});  #RNA Seqs??
      $gus_na_seq->setLength($bp_seq->length());
   
   return $gus_na_seq;
}


# ----------------------------------------------------------
# Make and NAEntry 
sub makeNAEntry {
   my ($self, $bp_seq) = @_;
   
   my $gus_naentry = GUS::Model::DoTS::NAEntry->new();
      $gus_naentry->setSourceId($bp_seq->accession_number());
      $gus_naentry->setDivision($bp_seq->division());
      $gus_naentry->setVersion($bp_seq->seq_version());
   return $gus_naentry;
}


# ----------------------------------------------------------
# Make your SecondaryACCs
sub makeSecAccs {
   my ($self, $bp_seq, $secAcc, $dbRlsId) = @_;

   my $gus_accsentry = GUS::Model::DoTS::SecondaryAccs->new();
      $gus_accsentry->setSourceId($bp_seq->accession_number());
      $gus_accsentry->setSecondaryAccs($secAcc);
      $gus_accsentry->setExternalDatabaseReleaseId($dbRlsId);
   return $gus_accsentry;
}


# ----------------------------------------------------------
# Make your Reference
sub makeReference{
     my  ($self, $reference) = @_;

          my $ref_hash_ref = $reference->hash_tree();
          my $gus_reference = GUS::Model::SRes::Reference->new() ;
          for my $key (keys %{$ref_hash_ref}) {
	     $gus_reference->setAuthor($ref_hash_ref->{'authors'});
	     $gus_reference->setTitle($ref_hash_ref->{'title'});
	     $gus_reference->setJournalOrBookName($ref_hash_ref->{'location'});
          }

          unless ($gus_reference->retrieveFromDB())  {
               $gus_reference->submit();
          }

          my $gus_ref_id = $gus_reference->getId();
          my $gus_ref_link = GUS::Model::DoTS::NASequenceRef->new({'reference_id'=>$gus_ref_id}); 

return $gus_ref_link;
}


# ----------------------------------------------------------
# Load your keywords 
sub makeKeyword{
   my ($self, $keyword) = @_;

   my $gus_keyword = GUS::Model::DoTS::Keyword->new({'keyword'=>$keyword}); 

      unless ($gus_keyword->retrieveFromDB())  {
           $gus_keyword->submit();
      }

   my $gus_key_id = $gus_keyword->getId();
   my $gus_key_link = GUS::Model::DoTS::NASequenceKeyword->new({'keyword_id'=>$gus_key_id}); 

return $gus_key_link;
}


# ----------------------------------------------------------
# Load your comments 
sub makeComment{
   my ($self, $comment) = @_;

   my $gus_comnt = GUS::Model::DoTS::NAComment->new({'comment_string'=>$comment}); 

return $gus_comnt;
}


# ----------------------------------------------------------
# Load your features
# ----------------------------------------------------------

#------------------------
# Process Tree
sub makeFeature {
   my ($self, $inputFeature, $mapper, $seqId) = @_; 
 
   #C.parvum short contigs containing only rRNAs create exonless genes because of error in unflattener
   #these lines are a very, very ugly hack to fix this problem.  Hopefully only temporary 
   #turn the rRNA flag off;
   my $rRnaFlag = 0;  #TOTAL HACK
 
   # map the immediate input feature into a gus feature
   my $gusFeature = $self->makeImmediateFeature($inputFeature, $mapper, $seqId);
  
   #if it is an rRNA, flag it bad!
   if ($inputFeature->primary_tag() eq 'rRNA') { $rRnaFlag = 1; }  #TOTAL HACK
 
   # recurse through the children
   foreach my $inputChildFeature ($inputFeature->get_SeqFeatures()) {
      my $gusChildFeature = $self->makeFeature($inputChildFeature, $mapper, $seqId);
      #set the flag good!
      $rRnaFlag = 0;  #TOTAL HACK
      $gusFeature->addChild($gusChildFeature);
   }

   #if flag still bad, add an exon!
  if ($rRnaFlag == 1) {
    my $hackFeature = GUS::Model::DoTS::ExonFeature->new();
       $hackFeature->setNaSequenceId($seqId);
       $hackFeature->setName('Exon');
       $hackFeature->addChild($self->makeLocation($inputFeature->location(),$inputFeature->strand()));
       #$hackFeature->setSequenceOntologyId();
    $gusFeature->addChild($hackFeature);
  }  
   
   return $gusFeature;
}


#------------------------
# Make each feature-set
sub makeImmediateFeature {
   my ($self, $inputFeature, $mapper, $seqId) = @_;
   
   my $featureMap = $mapper->{$inputFeature->primary_tag()};
   my $featureMapper = ApiComplexa::DataLoad::BioperlFeatureMapper->new();
   my $gusObj = $featureMapper->getGusTable($featureMap);
   my $soFeat = $featureMapper->getSOFeature($featureMap);
   my @transformArray = split(/\./,$gusObj);
   $gusObj="GUS::Model::DoTS::@transformArray[1]"; #All objects are DoTS.NaSequenceImp views
      my $gusFeature = $gusObj->new(); 

   $gusFeature->setSequenceOntologyId($self->getSOId($soFeat));  #use a cache object instead of a function
   $gusFeature->setNaSequenceId($seqId);
   $gusFeature->setName($inputFeature->primary_tag());

   $gusFeature->addChild($self->makeLocation($inputFeature->location(),$inputFeature->strand()));

   foreach my $tag ($inputFeature->get_all_tags()) {
      #future suggestion: special not if then, special can also have a column value or be lost
      if ($featureMapper->isSpecialCase($featureMap, $tag)) {
        my @tagValues = $inputFeature->get_tag_values($tag);
          foreach my $tagValue (@tagValues) {
            $gusFeature->addChild($self->makeSpecial($tag,$tagValue,$featureMapper,$inputFeature,$featureMap));
          }
      } else {
         unless ($featureMapper->isLost($featureMap, $tag)) {
            my $gusColumnName = $featureMapper->getGusColumn($featureMap, $tag);
               if (!$gusColumnName) { 
                  #and if there is a tag (i.e. it is not a featureless gene)
                  #Note: we do have featureless genes, so we need to test for empty tags
                  unless (!$tag) {die "invalid tag, No Mapping [$tag]\n";}  }
            my @tagValues = $inputFeature->get_tag_values($tag);
            if (scalar(@tagValues) != 1) {
               #die "invalid tag: more than one value\n"; }
               #snoRNA creates a bunch of empty values! Ignore and keep going.
            }
   if (scalar(@tagValues) == 1) { 
      if (@tagValues[0] ne "_no_value") { 
         $gusFeature->set($gusColumnName, $tagValues[0]);}  }
         }
      }
   }
   return $gusFeature;
}


# ----------------------------------------------------------
# Make Your Feature Location
sub makeLocation {
   my ($self, $f_location, $strand) = @_;

     if ($strand == 0) {$strand = '';}
     if ($strand == 1) {$strand = 0;}
     if ($strand == -1) {$strand = 1;}
   
   my $min_start = $f_location->min_start();
   my $max_start = $f_location->max_start();
   my $min_end = $f_location->min_end();
   my $max_end = $f_location->max_end();
   my $start_pos_type = $f_location->start_pos_type();
   my $end_pos_type = $f_location->end_pos_type();
   my $location_type = $f_location->location_type();
   my $start = $f_location->start();
   my $end = $f_location->end();

   my $gus_location = GUS::Model::DoTS::NALocation->new();
     $gus_location->setStartMax($max_start);
     $gus_location->setStartMin($min_start);
     $gus_location->setEndMax($max_end);
     $gus_location->setEndMin($min_end);
     $gus_location->setIsReversed($strand);
     $gus_location->setLocationType($location_type);

   return $gus_location;
}



# ----------------------------------------------------------
# Feature Checksums 
sub checksumDigest {
#re-write this whole thing.  it sucks
   my ($self, $feature) = @_;

   my $md5 = Digest::MD5->new;
#Use dumper as quick stringification instead of overloading "".
   $Data::Dumper::Terse = 1; 
   $Data::Dumper::Indent = 0;
        my @DumpStr = Dumper($feature);
      foreach my $item (@DumpStr) { $md5->add($item);}
   my $digest = $md5->b64digest;
return $digest;
}

# ----------------------------------------------------------
# Handler for special cases
# ----------------------------------------------------------

sub makeSpecial {
   my ($self, $tag, $value, $featureMapper, $inputFeature, $featureMap) = @_;
   
   my $specialcase = $featureMapper->isSpecialCase($featureMap,$tag);

      if ($specialcase eq 'dbxref') {
         my $special = $self->buildDbXRef($tag,$value);
         return $special; }
      elsif ($specialcase eq 'product') {
         my $special = $self->buildProtein($tag,$value);
         return $special; }
      elsif ($specialcase eq 'note') {
         my $special = $self->buildNote($tag,$value);
         return $special; }
      elsif ($specialcase eq 'gene') {
         my $special = $self->buildGene($tag,$value);
         return $special; }
      elsif ($specialcase eq 'aaseq') {
         my $special = $self->buildTranslatedAAFeature($tag,$value);
         return $special; }
      else { die "Un-handled Special Case: $specialcase"; }
}


#---------------------------------------
# All my special cases
#---------------------------------------
sub buildGene {
  my ($self, $tag, $value) = @_;
  my $geneID = &getNAGeneId($value);
  my $gene = GUS::Model::DoTS::NAFeatureNAGene->new();
  $gene->setNaGeneId($geneID);
  return $gene;
}

sub getNAGeneId {   
  my ($self, $geneName) = @_;
  my $trunNam = substr($geneName,0,300);
    my $gene = GUS::Model::DoTS::NAGene->new({'name' => $trunNam});
    unless ($gene->retrieveFromDB()){
      $gene->setIsVerified(0);
      $gene->submit();
    }
    my $geneID = $gene->getId();
  return $geneID;
}


#-----------
sub buildDbXRef {
   my ($self, $tag, $value) = @_;

   my $entry = GUS::Model::DoTS::DbRefNAFeature->new();
   my $id = &getDbXRefId($value);
   $entry->setDbRefId($id);

   ## If DbRef is outside of Genbank, then link directly to sequence
   #if (!($value =~ /taxon|GI|pseudo|dbSTS|dbEST/i)) {
   #  my $o2 = GUS::Model::DoTS::DbRefNASequence->new();
   #  $o2->setDbRefId($id);
   #}
   #else {
   # my $id = &getDbXRefId($value);}

   return $entry;

}

sub getDbXRefId {
   my $dbval = shift;
   my ($db,$id,$sid)= split(/\:/, $dbval);
   my $dbref = GUS::Model::SRes::DbRef->new({'external_database_release_id' => &getDbRelId($db),'primary_identifier' => $id});

   if ($sid) {
      $dbref->setSecondaryIdentifier($sid); }
   unless ($dbref->retrieveFromDB()) {
      $dbref->submit(); }

   my $dbId = $dbref->getId();

   return $dbId;
}

sub getDbRelId
{
   my $name = shift;
   my $external_db_rel_id;
   my $external_db_id;

   my $externalDatabaseRow = GUS::Model::SRes::ExternalDatabase->new({"name" => $name});
   $externalDatabaseRow->retrieveFromDB();

   if (! $externalDatabaseRow->getId()) {
      $externalDatabaseRow->submit();
   }

   $external_db_id = $externalDatabaseRow->getId();
   my $version = 'unknown';
   my $release_date = 'sysdate';
   my $externalDatabaseRelRow = GUS::Model::SRes::ExternalDatabaseRelease->new ({'external_database_id'=>$external_db_id,'release_date'=>$release_date, 'version'=>$version});
   $externalDatabaseRelRow->submit();
   $external_db_rel_id = $externalDatabaseRelRow->getExternalDatabaseReleaseId();

   return $external_db_rel_id;
}


#-----------
sub buildNote {
  my ($self, $tag, $value) = @_;
  my %note = ('comment_string' => substr($value, 0, 4000));
  return GUS::Model::DoTS::NAFeatureComment->new(\%note);
}


#-----------
sub buildProtein {
   my ($self, $tag, $value) = @_;

      my $name = substr($value,0,300);
      my $product = &getNaProteinId($name);
      my $entry = GUS::Model::DoTS::NAFeatureNAProtein->new();

      $entry->setNaProteinId($product);

   return $entry;
}

sub getNaProteinId {
   my $product = shift;

   my $protein = GUS::Model::DoTS::NAProtein->new({'name' => $product});

   unless ($protein->retrieveFromDB()){  
      $protein->setIsVerified(0);
      $protein->submit();
   }

   my $proteinID = $protein->getId();

   return $proteinID;
}

#-----------
sub buildTranslatedAAFeature {
   my ($self, $tag, $value) = @_;

      my $transAaFeat = GUS::Model::DoTS::TranslatedAAFeature->new();
      my $aaSeqId = &buildTranslatedAASequence($value);
      $transAaFeat->setAaSequenceId($aaSeqId);
      $transAaFeat->setIsPredicted(1);
# cqan we get the SO id down here!?!?!?!?!?
#number of segments = 1
#is reveresed
# is simple down here?
#a lot of this stuff is redundan across tables.......
#pass source ID down?????

   return $transAaFeat;
}

sub buildTranslatedAASequence {
   my $sequence = shift;

   my $aaSeq = GUS::Model::DoTS::TranslatedAASequence->new({'sequence' => $sequence});
#I am still working on this, I have programmed around this bug in other plugins.  I am not sure what is causing it, so it remains an open item for now.
#bug in object5 layer if we do a retrieve from first.  Here is the stack trace:
#(NO time to debug now, will get back to in 
#X
#MSKINLLNLKLVKKFENEDKYYEKGIKISANAIRISMRILLLFLFALIFSISSINGSNLSESPVDTRAKYGIVSHPEERSCKEKLLKTFSCLKLHSLLVKVKYIYVKFKTLLTYLFTYFKESDIDLEGIRDIVLNEIAQLSLENQAIVSVYVRKSCEREFPGFSTPMLKDFDPNASRHHVAPLSESKFEKSYVTQTLEILFRKNSKIKKIIKRADQLTTLKLCLSRLTFNLYRLAVFCQTAIKSLIKAILKANPNCKQFLSYAKSRLPLSSGGYDTSSSSSDEERYDEYFEKMKTYLPGGSSGGASGGASGGASGGDSGGDSGGASGGASGGASGGDSGGDSGGDSGGPTATQSGYNQYQQLRGISKVFRTSDKKETTSSLVCTCTSDKFSSRTCVCRPCAMRDNRGSTDSSIQPSCEIELPKKQKKALPKINLPCGYIPNPGDLCPIPLKTNKDFVVRKQNLESILSLPLRVTLQELDIEDISTDEELFCTEDFIKRPQEKKKLCLADLKKIREEPVEQPCMKSPDKSEMSKTKKIQRPSSPESSKFPLAHQLGLMQLQNFKTKDVPSKRFPRTRNTAVSRSHSTKHPRPLQTGDTSDDTKPHVSIPHLCSEARQSIQKPVLYSPTVDGGESKRQLGPDPSVRPKTTRPQLKIEDHSSHSTHRPRRRVEVVCRDGDYESRKASNLEEQLASLKISLNDNRSSHFTGGHGGHGGHGGQSSHRERSKNRERSRNRERSRNRERSGNRESGAKMASKVTYDGSGSRCARGGSSKEPMLLNAPTSMGGSSSSGSAASLDKYDLNDILEQSDY
#DBD::Oracle::db prepare failed: ORA-00932: inconsistent datatypes: expected - got CLOB (DBD ERROR: OCIStmtExecute/Describe) at /var/local/GUS/gus_home/lib/perl/GUS/ObjRelP/DbiRow.pm line 247, <GEN23> line 31571.
#Can't call method "execute" on an undefined value at /var/local/GUS/gus_home/lib/perl/GUS/ObjRelP/DbiRow.pm line 251, <GEN23> line 31571.

#   unless ($aaSeq->retrieveFromDB()){  
      #$protein->setIsVerified(0);
      $aaSeq->submit();
      #} 

   my $aaSeqId = $aaSeq->getId();

   return $aaSeqId;
}


# ----------------------------------------------------------
# Get SO Id 
# ----------------------------------------------------------

sub getSOId {
   my ($self, $SOname) = @_;
   my $SOId;
  
  unless ($SOname eq '') {  #need to handle non-existent so ids because source doesn't have any... not graceful
   my $so = GUS::Model::SRes::SequenceOntology->new({'so_id' => $SOname});
   $so->retrieveFromDB() || die "Failed to retrieve SO Id '$SOname'";
   my $SOId = $so->getId(); }
   
return $SOId;
}



# ----------------------------------------------------------
# Get Sequence Type Id 
# ----------------------------------------------------------

sub getSeqType {
   my $alphabet = shift;

   my $soup = GUS::Model::DoTS::SequenceType->new({'name' => $alphabet});
   $soup->retrieveFromDB() || die "Failed to retrieve Seq Type";
   my $STId = $soup->getId();
   
return $STId;
}


sub getTaxonId { 
   my ($self, $bp_seq_in) = @_;
   my $taxon_id;

   my $spec = $bp_seq_in->species();
   my $genName = $spec->genus();
   my $spcName = $spec->species();
   my $sci_name = "$genName $spcName";

   my $taxonRow = GUS::Model::SRes::TaxonName->new({"name" => $sci_name});
   if ($taxonRow->retrieveFromDB()) {
      $taxon_id = $taxonRow->getTaxonId(); }
   else {$taxon_id=1;}
   return $taxon_id;
  }


# ----------------------------------------------------------
# Dump your process log to file. 
# ----------------------------------------------------------
sub dumpLog {
  my ($self) = @_;

  my $reStrt = $self->getArg('fail_dir'); 
  open(MYLOG, ">$reStrt/las.log");
  my $features = $self->{'Feat:'};
  my $sequences = $self->{'Seq:'};
  foreach my $item (keys %$features) {
    print MYLOG "Feat:$item\n";
    }
  foreach my $item (keys %$sequences) {
    print MYLOG "Seq:$item\n";
    }
  close MYLOG;
}


# ----------------------------------------------------------
# Load Arguments
# ----------------------------------------------------------

sub getArgsDeclaration {
my $argsDeclaration  =
[
fileArg({name => 'map_xml',
         descr => 'XML file with Mapping of Sequence Feature from BioPerl to GUS',
         constraintFunc=> undef,
         reqd  => 1,
         isList => 0,
         mustExist => 1,
         format=>'XML'
        }),

fileArg({name => 'data_file',
         descr => 'text file containing external sequence annotation data',
         constraintFunc=> undef,
         reqd  => 1,
         isList => 0,
         mustExist => 1,
         format=>'Text'
        }),

stringArg({name => 'seq_type',
       descr => 'sequence type id',
       constraintFunc=> undef,
       reqd  => 1,
       isList => 0
      }),

stringArg({name => 'file_format',
       descr => 'Format of external data being loaded',
       constraintFunc=> undef,
       reqd  => 1,
       isList => 0
      }),

stringArg({name => 'extDbName',
       descr => 'External database from whence this data came',
       constraintFunc=> undef,
       reqd  => 1,
       isList => 0
      }),

stringArg({name => 'extDbRlsVer',
       descr => 'Version of external database from whence this data came',
       constraintFunc=> undef,
       reqd  => 1,
       isList => 0
      }),

stringArg({name => 'downloadURL',
       descr => 'URL from whence this file came should include filename',
       constraintFunc=> undef,
       reqd  => 0,
       isList => 0
      }),

stringArg({name => 'extDbRlsDate',
       descr => 'Release date of external data source',
       constraintFunc=> undef,
       reqd  => 0,
       isList => 0
      }),

stringArg({name => 'filename',
       descr => 'Name of the file in the resource (including path)',
       constraintFunc=> undef,
       reqd  => 0,
       isList => 0
      }),

stringArg({name => 'description',
       descr => 'a quoted description of the resource, should include the download date',
       constraintFunc=> undef,
       reqd  => 0,
       isList => 0
      }),

stringArg({name => 'fail_dir',
       descr => 'where to place a failure log',
       constraintFunc=> undef,
       reqd  => 1,
       isList => 0
      }),

stringArg({name => 'project_name',
       descr => 'project this data belongs to - must in entered in GUS',
       constraintFunc=> undef,
       reqd  => 1,
       isList => 0
      }),

integerArg({name => 'restart_point',
       descr => 'Point at which to restart submitting data.  Format = SEQ:[ID] or FEAT:[ID]',
       constraintFunc=> undef,
       reqd  => 0,
       isList => 0
      }),

integerArg({name => 'test_number',
       descr => 'number of entries to do test on',
       constraintFunc=> undef,
       reqd  => 0,
       isList => 0
      }),

booleanArg({name => 'is_update_mode',
       descr => 'whether this is an update mode',
       constraintFunc=> undef,
       reqd  => 0,
       isList => 0,
       default => 0,
      }),
];

return $argsDeclaration;
}


# ----------------------------------------------------------
# Failure Handlers
# ----------------------------------------------------------

sub seqDonePreviously {
  my ($self, $bioperlSeq) = @_;

#check if the accession is in the seq cache

return 0;
}

sub handleSeqFailure {
  my ($self, $bioperlSeq, $msg) = @_;

#print out both caches to file
}

sub featDonePreviously {
  my ($self, $featureDigest) = @_;

#check if it is in the checksum cache
return 0;
}

sub handleFeatureFailure {
  my ($self, $bioperlFeature, $msg) = @_;

#print all caches to file
$self->dumpLog();
exit;
}


#_---------------------
#startup logging
sub startUpLog {
   my $self = shift;

        my $failDir = $self->getArg('fail_dir');
        my $format = $self->getArg('file_format');
        my $dataFile = $self->getArg('data_file');

        $self->logAlgInvocationId();
        $self->logCommit();
        $self->logArgs();

        my $startTime = `date`;
        $self->log("STATUS","Time now: $startTime");
        $self->log("LoadAnnotatedSeqs");
}

# ----------------------------------------------------------
# Documentation
# ----------------------------------------------------------

sub getDocumentation {

my $description = <<NOTES;
This is the first version of this application, and it does not handle updates at this time.

Also note that we need to move a couple more arguments to the command line!!

Finally, it only handles four special cases that we encounter in the C.parvum and C.hominis GenBank Files.
NOTES

my $purpose = <<PURPOSE;
This application will load any annotated sequence file into GUS via BioPerl's Bio::Seq interface so long as there is a valid Bioperl format module.
PURPOSE

my $purposeBrief = <<PURPOSEBRIEF;
Load any and all annotated sequence data formats into GUS.
PURPOSEBRIEF

my $syntax = <<SYNTAX;
ga GUS::Common::Plugin::LoadAnnotatedSeqs
--map_xml [xml file containg correct feature->gus feature mapping]
--data_file [your data file]
--file_format [valid BioPerl name for the fprmat of your data file (e.g. genbank)
--db_rls_id=[The gus external database release id for this data set
--commit
SYNTAX

my $notes = <<NOTES;
This is only in insert mode right now, and has only been tested for GenBank.  It is still a new plugin.
NOTES

my $tablesAffected = <<AFFECT;
All views of NaFeatureImp, DbRefNaSequence, NAProtein, NaProteinNaFeature, NaSequenceImp
AFFECT

my $tablesDependedOn = <<TABD;
A whole bunch, I will have to go through this list soon.
TABD

my $howToRestart = <<RESTART;
Kill and re-submit it.
RESTART

my $failureCases = <<FAIL;
It just craps out and you figure out what you need to add.  Oy vey.
FAIL

my $documentation = {purpose=>$purpose, purposeBrief=>$purposeBrief,tablesAffected=>$tablesAffected,tablesDependedOn=>$tablesDependedOn,howToRestart=>$howToRestart,failureCases=>$failureCases,notes=>$notes};

return ($documentation);

}


return 1;



