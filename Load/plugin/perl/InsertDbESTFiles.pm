package ApiCommonData::Load::Plugin::InsertDbESTFiles;
@ISA = qw(GUS::PluginMgr::Plugin);

use strict;

use DBI;
use GUS::PluginMgr::Plugin;
use GUS::Model::SRes::ExternalDatabase;
use GUS::Model::SRes::ExternalDatabaseRelease;
use GUS::Model::DoTS::SequenceType;
use GUS::Model::DoTS::ExternalNASequence;
use GUS::Model::DoTS::Source;
use GUS::Model::DoTS::EST;
use GUS::Model::DoTS::Library;
use GUS::Model::DoTS::Clone;
use GUS::Model::DoTS::CloneSet;
use GUS::Model::DoTS::CloneInSet;
use GUS::Model::DoTS::NASequenceRef;
use GUS::Model::SRes::Contact;
use GUS::Model::SRes::Reference;
use GUS::Model::SRes::TaxonName;
use Bio::PrimarySeq; 
use Bio::Tools::SeqStats;


sub getArgsDeclaration {
my $argsDeclaration  =
[

fileArg({name => 'inputFile',
         descr => 'File with your DbEST entries.  This file must be a valid EST file downloaded from NCBI.  A copy of this format is at the end of the plugin.',
         constraintFunc=> undef,
         reqd  => 1,
         isList => 0,
         mustExist => 1,
         format=>'Text'
        }),

stringArg({name => 'extDbName',
       descr => 'External database of source sequences (if you are using source_ids rather than gus_ids)',
       constraintFunc=> undef,
       reqd  => 1,
       isList => 0
      }),

stringArg({name => 'extDbRlsVer',
       descr => 'Version of external database of source sequences',
       constraintFunc=> undef,
       reqd  => 1,
       isList => 0
      }),

fileArg({name => 'restartFile',
         descr => 'log file containing/for storing entries from last run/this run',
         constraintFunc=> undef,
         reqd  => 0,
         mustExist => 0,
         isList => 0,
         format=>'Text'
        }),

];

return $argsDeclaration;
}


sub getDocumentation {

my $description = <<NOTES;
NOTES

my $purpose = <<PURPOSE;
A plugin for loading ESTS into gus fro EST dbEST format test files.
PURPOSE

my $purposeBrief = <<PURPOSEBRIEF;
A plugin for loading ESTS into gus fro EST dbEST format test files.
PURPOSEBRIEF

my $syntax = <<SYNTAX;
SYNTAX

my $notes = <<NOTES;
A number of fields in DoTS.EST are calculated from dbEST fields.  Make sure your data agree with these.  There may be differences for some organisms.
In the future, we may want to expnad handling of clone-sets and developmental stage libraries.  Presently, none of this is loaded.
NOTES

my $tablesAffected = <<AFFECT;
DoTS.ExternalNASequence
DoTS.Library
DoTS.EST
SRes.Contact
SRes.Reference
DoTS.Clone
DoTS.CloneSet
DoTS.Source
AFFECT

my $tablesDependedOn = <<TABD;
DoTS.Taxon
DoTS.TaxonName
DoTS.ExternalDatabase
DoTS.ExternalDatabaseRelease
DoTS.SequenceType
SRes.SequenceOntology
TABD

my $howToRestart = <<RESTART;
Ultimately, this plugin will do a check via retrieval to avoid entering duplicates.  This functionality is not fully added yet due to an error in how retrieveFromDB() in the object layer handles Clobs.
RESTART

my $failureCases = <<FAIL;
None known.  Not all fields are mapped for the EST files.  Make sure yours appear in GUS, or add them to the plugin.   Missing fields in the plugin will not cause failure, they will just not appear in GUS.
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

      $self->initialize({requiredDbVersion => 3.5,
                     cvsRevision => '$Revision$',
                     name => ref($self),
                     argsDeclaration   => $args,
                     documentation     => $documentation
                    });
   return $self;
}


sub run {
    my $self = shift;

    my $extDb = $self->getExtDbRlsId($self->getArg('extDbName'),
                                     $self->getArg('extDbRlsVer'))
                or die "Couldn't retrieve external database!\n";
    my $seqType = $self->getSeqType();

    #SET THE EXTERNAL DATABASE NAME INTO THE CONTEXT
    my $file = $self->getArgs()->{'inputFile'} || die "No Such Input File";
    open (ESTs, "<$file");
    my ($est, $estCt, $section, $subCat, $content);

    while (<ESTs>) {
         if (/\|\|/) {
            my $gusSeq = $self->processEST($est, $seqType, $extDb);
            #unless ($gusSeq->retrieveFromDB()) { 
                $gusSeq->submit();
            #}
            $estCt++;
            undef $est;
         }
         else {
            ($section, $subCat, $content) = $self->parseLine(
                                   $section, $subCat, $content, $_);
            $est->{$section}->{$subCat} = $content;
         }
     }

    $self->log("Total Seqs Processed: $estCt\n");
    $self->log("Added Librarys:", $self->{'libCt'} );
    $self->log("Added Contacts:", $self->{'conCt'} );
    $self->log("Added References:", $self->{'sresRefCt'} );
}



sub parseLine {
  my ($self, $section, $subCat, $content, $lineIn) = @_;
  chomp($lineIn);
  $lineIn =~ s/\s+/ /;

       if ($lineIn =~ /^(\w+\s?\w*)$/) {
          $section = $1;
          $subCat = 'content';
          undef $content; 
       }
       elsif ($lineIn =~ /:/) {
          ($subCat, $content) = split(/:\s+/, $lineIn, 2);
       }
       else { 
          $content = "$content$lineIn"; }

  return ($section, $subCat, $content)
}




sub processEST {
   my ($self, $est, $seqType, $extDb) = @_;

    my $organism = $est->{'LIBRARY'}->{'Organism'};
    unless ($self->{$organism}) {
       $self->setTaxonId($organism);
    }

     my $gusSeq = $self->buildSequence($est, $seqType, $extDb);
         my $gusRefLink = $self->getOrCreateReference($est);
         $gusSeq->addChild($gusRefLink);
         #my $gusNaFeat = $self->buildSourceFeat($est);
         #$gusSeq->addChild($gusNaFeat);
    
     my $gusEST = $self->buildEST($est);
         my $gusLibId = $self->getOrCreateLibrary($est);
         my $gusConId = $self->getOrCreateContact($est);
         #my $gusCloneId = $self->getOrCreateClone($est, $gusLibId);
             $gusEST->setLibraryId($gusLibId);
             $gusEST->setContactId($gusConId);
             #$gusEST->setCloneId($gusLibId);

     $gusSeq->addChild($gusEST);

return $gusSeq;
}




sub buildSequence {
    my ($self, $est, $seqType, $extDb) = @_;

    my $organism = $est->{'LIBRARY'}->{'Organism'};
    my $seq = $est->{'SEQUENCE'}->{'content'};
    $seq =~ s/\s//g;

    my $gusSeq = GUS::Model::DoTS::ExternalNASequence->new();

    my $bioSeq = Bio::PrimarySeq->new(-seq=>$seq, 
                                          -alphabet=>'dna', 
                                          -id=>0);

    my $seqcount  =  Bio::Tools::SeqStats->new(-seq=>$bioSeq);
      #$gusSeq->setSourceId($est->{'IDENTIFIERS'}->{'EST name'});  #Changed per Mark's request
      $gusSeq->setSourceId($est->{'IDENTIFIERS'}->{'GenBank Acc'});
      $gusSeq->setSecondaryIdentifier($est->{'IDENTIFIERS'}->{'GenBank Acc'});
      $gusSeq->setName($est->{'IDENTIFIERS'}->{'EST name'});
      $gusSeq->setTaxonId($self->{$organism});
      $gusSeq->setSequenceVersion(0);
      $gusSeq->setExternalDatabaseReleaseId($extDb);
      $gusSeq->setDescription($est->{'COMMENTS'}->{'content'});
      $gusSeq->setSequenceTypeId($seqType);
      $gusSeq->setSequence($seq);
      $gusSeq->setACount(%$seqcount->{'A'});
      $gusSeq->setCCount(%$seqcount->{'C'});
      $gusSeq->setGCount(%$seqcount->{'G'});
      $gusSeq->setTCount(%$seqcount->{'T'});
      $gusSeq->setLength($bioSeq->length());

return $gusSeq;
}




#sub buildSourceFeat {
#    my ($self, $est) = @_;
#}




#sub getOrCreateClone {
#    my ($self, $est, $gusLibId) = @_;

#return $gusCloneId;
#}




sub buildEST {
    my ($self, $est) = @_;

    #presently hardcoded
    my $pEnd = 5;
    my $seqLeng = 0;
    my $pRev = 2;
    my $pflr = 0;
    my $tpq = 0;

    my ($qualStart, $qualStop) = $self->getQuality($est);
    my ($polyA, $seqPrim) = $self->getPrimerInfo($est);

    my $gusEST = GUS::Model::DoTS::EST->new( {
          'dbest_id_est' => $est->{'IDENTIFIERS'}->{'dbEST Id'},
          'accession' => $est->{'IDENTIFIERS'}->{'GenBank Acc'},
          'seq_primer' => $seqPrim,
          'polya_signal' => $polyA,
          'quality_start' => $qualStart, 
          'quality_stop' => $qualStop,
          'P_End' => $pEnd,
          'seq_length' => $seqLeng,
          'possibly_reversed' => $pRev,
          'putative_full_length_read' => $pflr,
          'trace_poor_quality' => $tpq,
    } );

return $gusEST;
}





sub getOrCreateReference {
    my ($self, $est) = @_;

    #Presently does not support multiple citations
    my $gusReference = GUS::Model::SRes::Reference->new( {
                    'author' => $est->{'CITATIONS'}->{'Authors'},
                    'title' => $est->{'CITATIONS'}->{'Title'},
                    'journal_or_book_name' => $est->{'CITATIONS'}->{'Citation'},
                    #'journal_or_book_name' => $est->{'CITATIONS'}->{'Citation'}, should be unpacked
                    } );

    unless ($gusReference->retrieveFromDB()) {
             $gusReference->submit();
             $self->{'sresRefCt'}++;
    }
    my $gusId = $gusReference->getId();

    my $gusLinkTabl = GUS::Model::DoTS::NASequenceRef->new( {
                  'reference_id' => $gusId, } );
   
return $gusLinkTabl;
}




sub getOrCreateLibrary {
    my ($self, $est) = @_;

    my $organism = $est->{'LIBRARY'}->{'Organism'};
    my $gusLibrary = GUS::Model::DoTS::Library->new( {
                    'taxon_id' => $self->{$organism},
                    'is_image' => 0,
                    'dbest_id' => $est->{'LIBRARY'}->{'dbEST lib id'},
                    'dbest_name' => $est->{'LIBRARY'}->{'Lib Name'},
                    'dbest_organism' => $est->{'LIBRARY'}->{'Organism'},
                    'strain' => $est->{'LIBRARY'}->{'Strain'},
                    'cultivar' => $est->{'LIBRARY'}->{'Cultivar'},
                    'sex' => $est->{'LIBRARY'}->{'Sex'},
                    'dbest_organ' => $est->{'LIBRARY'}->{'Organ'},
                    'tissue_type' => $est->{'LIBRARY'}->{'Tissue'},
                    'cell_type' => $est->{'LIBRARY'}->{'Cell_type'},
                    'cell_line' => $est->{'LIBRARY'}->{'Cell_line'},
                    'stage' => $est->{'LIBRARY'}->{'Develop. stage'},
                    'host' => $est->{'LIBRARY'}->{'Lab host'},
                    'vector' => $est->{'LIBRARY'}->{'Vector'},
                    'vector_type' => $est->{'LIBRARY'}->{'Vector type'},
                    're_1' => $est->{'LIBRARY'}->{'R. Site 1'},
                    're_2' => $est->{'LIBRARY'}->{'R. Site 2'},
                    } );

    unless ($gusLibrary->retrieveFromDB()) {
         $gusLibrary->setCommentString($est->{'LIBRARY'}->{'Description'});
         $gusLibrary->submit();
         $self->{'libCt'}++;
    }
    my $gusId = $gusLibrary->getId();
   
return $gusId;
}



sub getOrCreateContact {
    my ($self, $est) = @_;

    my $gusContact = GUS::Model::SRes::Contact->new( {
                    'name' => $est->{'SUBMITTER'}->{'Name'},
                    'fax' => $est->{'SUBMITTER'}->{'Fax'},
                    'phone' => $est->{'SUBMITTER'}->{'Tel'},
                    'email' => $est->{'SUBMITTER'}->{'E-mail'},
                    'address1' => $est->{'SUBMITTER'}->{'Institution'},
                    'address2' => $est->{'SUBMITTER'}->{'Address'}, #process into sub-fields
                    #'affiliation' => $est->{'SUBMITTER'}->{'Lab'},  Aff Id, not workable
                    } );

    unless ($gusContact->retrieveFromDB()) {
             $gusContact->submit();
             $self->{'conCt'}++;
    }
    my $gusId = $gusContact->getId();
   
return $gusId;
}




sub getQuality {
  my ($self, $est) = @_;

      my $quality = $est->{'SEQUENCE'}->{'Quality'},
      my ($qualStart, $qualStop) = 1;
      if ($quality =~ /High quality sequence starts at base: (\d+)/) {
          $qualStart = $1;
      }
      if ($quality =~ /High quality sequence stops at base: (\d+)/) {
          $qualStop = $1;
      }

 return ($qualStart, $qualStop);
}


sub getPrimerInfo {
  my ($self, $est) = @_;
          
          my $polyA; 
          my $seqPrim = $est->{'PRIMERS'}->{'Sequencing'};
          if (($est->{'PRIMERS'}->{'PolyA Tail'}) ne 'unknown') {
              $polyA = 1,
          }
          else {
              $polyA = 0,
          }

 return ($polyA, $seqPrim);
}



sub setTaxonId{
   my ($self, $organism) = @_;

   my $taxon = GUS::Model::SRes::TaxonName->new( { 
                      'name' => $organism, } );

   $taxon->retrieveFromDB() || die "invalid organism name: $organism";
   $self->{$organism} = $taxon->get('taxon_id') || die "Failed to retrieve SRes::TaxonName for name = $organism\n";
return 1;
}


sub getSeqType {
   my $self = shift;

   my $gusSeqTypObj = GUS::Model::DoTS::SequenceType->new( {
                       'name' => 'EST', } );

   $gusSeqTypObj->retrieveFromDB() || die 'Sequence Type Table Not Initialized';
   my $seqType = $gusSeqTypObj->getId();

return $seqType;
}


1;



=cut   ======================================================================
IDENTIFIERS
                                                                                                                             
dbEST Id:       806707
EST name:       CpEST.006
GenBank Acc:    AA167878
GenBank gi:     1746046
                                                                                                                             
CLONE INFO
Clone Id:       (5')
DNA type:       cDNA
                                                                                                                             
PRIMERS
Sequencing:     M13 reverse
PolyA Tail:     Unknown
                                                                                                                             
SEQUENCE
                CTAGAGGTGACTTGCCTAGTTTAAGTTTATGGGCAAAAAAAATGAAGGACTCTACTCTTG
                TAAGATCTGCTGATGTTATTCAAGAGATTTTCAATCATTTAAAGTCTAACAGAATTGATG
                TTAATCTTTTACCACTGGGATGGGAATCTGTATTGAATAAGAGTATTGAGCTTAAGAAGA
                AGATGATGGATTTAGATGACATTAAGAGTGTTTCAAGAAAAGCAGTTCTTTCTGCAGCCT
                GGGAAGCATTTGACTATTGGATAACTGTACAAGACAGTGACTTACCATCTTCTCCAGAAG
                AATGGTGGGATCATGGGCCAGCTCAATTATTCAAGCAGCTCGAATCAAAGATTTCATATG
                CTACTGAATTGAATCTTGAAGGTCTAATGGAAGCTGCAAAAAGCTACTCGGCTCTTCGTT
                TTGCATATGGAAATACTAAGGCCGCTCAATCTAATAACTCTGAAGAACTCAAGTCGTTAT
                CCGAGGAGTCAGCAATTAATTTATTACTAAGACTGGTTTTAAAGGGATGCCCAAA
Quality:        High quality sequence stops at base: 535
                                                                                                                             
Entry Created:  Dec 19 1996
Last Updated:   Aug 23 2000
                                                                                                                             
COMMENTS
                Submitted sequence has been edited to remove vector
                sequences 5' to the insert, to correct miscalled bases and
                assign uncalled (N) bases throughout the sequence, and to
                terminate when base-calling became ambiguous.
                                                                                                                             
PUTATIVE ID     Assigned by submitter
                unidentified
                                                                                                                             
LIBRARY
dbEST lib id:   577
Lib Name:       uniZAPCpIOWAsporoLib1
Organism:       Cryptosporidium parvum
Strain:         IOWA
Develop. stage: sporozoite
Lab host:       E. coli XL1 Blue MRF' Kan
Vector:         UniZAP XR
R. Site 1:      EcoR I
R. Site 2:      Xho I
Description:    Total RNA was isolated from purified Cryptosporidium parvum
                sporozoites using TRIZOL reagent (GIBCO-BRL). Directional
                cDNA was synthesized by first-strand priming with a Xho
                I-oligo d(T) linker-primer, second-stranding with RNase H
                and DNA polymerase I, ligation of EcoR I linkers, and
                digestion with Xho I, all using the Stratagene ZAP-cDNA
                synthesis kit. The cDNA was cloned into the EcoR I and Xho I
                sites of Lambda Uni-ZAP XR vector; the primary library was
                >97% recombinant and contained 1.3 X 10(6) independent
                clones with an ca. average insert size of 1.3 kb. Based on
                open reading frame (orf) analysis of the first 64 sequence
                tags we estimate that up to one-third of the library is
                composed of genomic DNA clones since approximately 15% of
                the orfs were incorrectly oriented on the antisense strand.
                                                                                                                             
SUBMITTER
Name:           Nelson, R. G.
Lab:            Depts. of Medicine & Pharmaceutical Chemistry
Institution:    San Francisco General Hospital-University of California, San
                Francisco
Address:        Box 0811, San Francisco, CA 94143-0811, USA
Tel:            415 206 8846
Fax:            415 206 3353
E-mail:         malaria@itsa.ucsf.edu
                                                                                                                             
CITATIONS
PubMed ID:      10717299
Title:          Preliminary profile of the Cryptosporidium parvum genome: an
                expressed sequence tag and genome survey sequence analysis
Authors:        Strong,W.B., Nelson,R.G.
Citation:       Mol. Biochem. Parasitol. 107 (1): 1-32 2000


MAP DATA

||
