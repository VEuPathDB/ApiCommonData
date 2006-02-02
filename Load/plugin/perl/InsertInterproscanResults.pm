package ApiCommonData::Load::Plugin::InsertInterproscanResults;
@ISA = qw(GUS::PluginMgr::Plugin);

use strict;

use DBI;
use XML::Twig;
use XML::Simple;
use Data::Dumper;
use GUS::PluginMgr::Plugin;
use GUS::Model::Core::Algorithm;
use GUS::Model::SRes::ExternalDatabase;
use GUS::Model::SRes::ExternalDatabaseRelease;
use GUS::Model::SRes::ExternalDatabaseEntry;
use GUS::Model::DoTS::PredictedAAFeature;
use GUS::Model::DoTS::DomainFeature;
use GUS::Model::DoTS::ExternalAASequence;
use GUS::Model::DoTS::TranslatedAASequence;
use GUS::Model::DoTS::AALocation;

use GUS::Model::SRes::GOEvidenceCode;
use GUS::Model::SRes::GOTerm;
use GUS::Model::SRes::GOSynonym;
use GUS::Model::DoTS::GOAssocInstEvidCode;
use GUS::Model::DoTS::GOAssociationInstanceLOE;
use GUS::Model::DoTS::GOAssociationInstance;
use GUS::Model::DoTS::GOAssociation;

sub getArgsDeclaration {
my $argsDeclaration  =
[

fileArg({name => 'resultFile',
         descr => 'XML file of interpro results',
         constraintFunc=> undef,
         reqd  => 1,
         isList => 0,
         mustExist => 1,
         format=>'Text'
        }),

fileArg({name => 'confFile',
         descr => 'XML file containing configuration for this plugin',
         constraintFunc=> undef,
         reqd  => 1,
         mustExist => 0,
         isList => 0,
         format=>'Text'
        }),

booleanArg({name => 'bootData',
         descr => 'Strict (not flagged, must have all databases bootstrapped) Loose (flagged - automatic loading of missing dbs)',
         constraintFunc=> undef,
         reqd  => 0,
         isList => 0,
         format=>'boolean'
        }),

stringArg({name => 'queryTable',
         descr => 'Table source of AA sequences in InterporAnalysis',
         constraintFunc=> undef,
         reqd  => 1,
         mustExist => 0,
         isList => 0,
         format=>'Text'
        }),

stringArg({name => 'extDbName',
       descr => 'External database of source sequences (if you are using source_ids rather than gus_ids)',
       constraintFunc=> undef,
       reqd  => 0,
       isList => 0
      }),

stringArg({name => 'extDbRlsVer',
       descr => 'Version of external database of source sequences',
       constraintFunc=> undef,
       reqd  => 0,
       isList => 0
      }),

stringArg({name => 'iprVer',
       descr => 'Version of iprscan algorithm you are running',
       constraintFunc=> undef,
       reqd  => 1,
       isList => 0
      }),

stringArg({name => 'iprDataVer',
       descr => 'version of interpro database release you are using',
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

booleanArg({name => 'useSourceId',
       descr => 'Use source_id to link back to AASequence view',
       constraintFunc=> undef,
       reqd  => 0,
       isList => 0,
       default => 0,
      }),

fileArg({name => 'versionFile',
         descr => 'xml file containing version information for the prediction algorithms.',
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
An application for loading the results output by InterproScan.  This application will load the hits for the specific database matches (e.g. Pfam, Prints, ProDom, Smart) as well as the GO classifications encountered.  The applications takes as input interpro XML.  Hits on databases are loaded into DoTS.DomainFeature.  GO Terms are loaded into DoTS.GOAssociation.  The interpro scan analysys needs to be run on ouput from gus where the sequence ids are aa_sequence_ids from either DoTS.ExternalAASequence or DoTS.TranslatedAASequence.
NOTES

my $purpose = <<PURPOSE;
Create DomainFeatures for various domain databases such as Pfam and Smart in GUS, and GOAssociatinos with GUS aa_sequences from InterproScan output.OB
PURPOSE

my $purposeBrief = <<PURPOSEBRIEF;
Load the contents of an Interproscan Match XML into GUS.
PURPOSEBRIEF

my $syntax = <<SYNTAX;
Standard Plugin Syntax.
SYNTAX

my $notes = <<NOTES;
We are not presently loading the InterproDB hits.  We are only loading the matches with the associated Databases and the GO classifications.  Also note that there is a bootstrapping plugin which runs off of the same configuration file as this plugin.The bootstrapping plugin InsertDomainDbs will read the file and pre-load the DatabaseEntries in SRes.ExternalDatabaseEntry.  You can then link from DoTS.DomainFeature to a specific SRes.ExternalDataseEntry via external_database_release_id and source_id to get the full name and description of the database entry for that hit.  Note that the external_databsae_release_ids are for the individual databases included in interpro.  Only the actual interpro hits themselves will use the release id for interpro itself.  A Pfam hit in interpro release 11.0 will point to Pfam 14.0, not interpro 11.0.  Also note, if you do not bootstrap, you can use the --bootData flag to create empty external_database_releases for all of the databases.  This will allow you to load your interpro results.  However, they will not point to anything in SRes.ExternalDatabaseEntry.OB
NOTES

my $tablesAffected = <<AFFECT;
DoTS.DomainFeature
DoTS.AALocation
DoTS.GOAssociation
DoTS.GOAssociationInstance
DoTS.GOAssociationInstanceLOE
DoTS.GOAssocInstEvidCode
AFFECT

my $tablesDependedOn = <<TABD;
DoTS.AASequenceImp
SRes.GOTerm
SRes.GOEvidenceCode
SRes.ExternalDatabaseRelease
SRes.ExternalDatabaseEntry
Core.TableInfo
TABD

my $howToRestart = <<RESTART;
No restart facilities at the present time.  All inserts are qualified with a RetrieveFromDb so you should be able to restart by rerunning and all previously loaded data will be skipped.
RESTART

my $failureCases = <<FAIL;
Most significant failure cases should happen early in the configuration of the plugin if it cannot load the XML file or if it finds that the configuration of the external databases is incorrect.
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

    $self->loadConfig();

    my $file = $self->getArgs()->{'resultFile'} || die "No Such Input File";

    my $twig = XML::Twig->new( twig_roots => {
                               protein => processTwig($self), 
                                             } );
    $twig->parsefile($file);
    $twig->purge;

    #Create ExternalDatabaseLinks  (SRes.ExternalDatabaseLink)

    my $logCnt = $self->{'protCount'};
    $self->log("Total Seqs Processed: $logCnt\n");
    $self->log("Added DBs:", @{$self->{'NewDBs'}} );
    $self->log("Added Algs:", @{$self->{'NewAlgs'}} );

}


sub processTwig {
   my $self = shift;

   return sub { 
    my $twig = shift; 

        my $gusObj = $self->processProteinResults($twig);
            ($self->{'protCount'})++;
        $self->undefPointerCache();

    $twig->purge(); 
   }
}


sub processProteinResults {
    my ($self, $twig) = @_;

    my $elt = $twig->root;
    my $protein = $elt->next_elt();
    my $aaId = $protein->att('id');
    
    my $tableName = $self->getArgs()->{'queryTable'};
    my $queryTable = "GUS::Model::DoTS::$tableName";

        if ($self->getArg('useSourceId')) {
           $aaId = $self->retSeqIdFromSrcId($aaId);
        }

    my $gusAASeq = $queryTable->new({ 'aa_sequence_id' => $aaId });
        $gusAASeq->retrieveFromDB() || die "no such AA sequence";

    my $eltn = 1;
    while (my $interpro = $elt->next_n_elt($eltn)) {
        my $match = $interpro->copy();
        my $mTree = $match->root;
        if ($interpro->tag() eq 'interpro') {
            unless ($interpro->att('id') eq 'noIPR') {
                my $ipr = $self->buildInterproMatch($mTree,$aaId);
                $ipr = $self->submitObjToGus($ipr);
            }
        }
        if ($interpro->tag() eq 'classification') {
            my $classId = $interpro->att('id');
            $self->buildClassification($aaId,$classId);
        }
        if ($interpro->tag() eq 'match') {
           if ($interpro->att('id') =~ /tmhmm/ or $interpro->att('id') =~ /signalp/) {
             #ignoring, use algorithems directly
           }
           else {
             my $gusDom = $self->buildParentDomain($mTree,$aaId); 
             $gusDom = $self->submitObjToGus($gusDom);
           }
       }
    $eltn++;
    }
return 1;
}


sub buildParentDomain {
    my ($self,$match,$aaId) = @_;

    my $id = $match->att('id');
    my $name = $match->att('name');
    my $dbName = $match->att('dbname');
    my $dbRel = $self->{$dbName};
    my ($algName, $score);

    my $parentDomain = GUS::Model::DoTS::DomainFeature->new( { 'name' => $name,
                                                             'source_id' => $id,
                                                             'external_database_release_id' => $dbRel,
                                                             'is_predicted' => 1 });
    my $parentLoc = { 'start_min' => 100000,
                      'start_max' => 100000,
                      'end_min' => 0,
                      'end_max' => 0 };

    my $numDoms = 1;

    my $eltn = 1;
    while (my $location = $match->next_n_elt($eltn)) {
       if ($location->tag() eq 'location') {
           $parentDomain->setNumberOfDomains( $numDoms++ );
           my $childDomain = $self->buildSubDomain( $match,$location );
           $childDomain->setAaSequenceId($aaId);
           $childDomain->setExternalDatabaseReleaseId($dbRel);
           my ($gusLoc, $parentLoc) = $self->buildLocation($location,$parentLoc);
           $childDomain->addChild($gusLoc);
           $parentDomain->addChild($childDomain);
       }
    $eltn++;
    }

    my $parentLocation = GUS::Model::DoTS::AALocation->new($parentLoc);
        $parentDomain->addChild($parentLocation);
        $parentDomain->setAaSequenceId($aaId);

return $parentDomain;
}


sub buildSubDomain {
   my ($self, $match, $location) = @_;

    my $id = $match->att('id');
    my $name = $match->att('name');
    my $score = $location->att('score');
    my $algName = $location->att('evidence');
    my $algId = $self->{'algorithms'}->{$algName};

          my $gusDom = GUS::Model::DoTS::DomainFeature->new({ 'name' => $name,
                                                             'source_id' => $id,
                                                             'is_predicted' => 1,
                                                             'algorithm_name' => $algName,
                                                             'prediction_algorithm_id' => $algId,
                                                             'score' => $score, });
return $gusDom;
}


sub buildLocation {
   my ($self, $location, $parentLoc) = @_;

   my $start = $location->att('start');
   my $end = $location->att('end');

   if ($parentLoc) { $parentLoc = $self->updateParentLoc($parentLoc,$start,$end); }

   my $gusLoc = GUS::Model::DoTS::AALocation->new({ 'start_min' => $start,
                                                   'start_max' => $start,
                                                   'end_min' => $end, 
                                                   'end_max' => $end, });
   return ($gusLoc, $parentLoc);
}



sub updateParentLoc {
 my ($self, $parentLoc, $start, $end) = @_;

   if ($start < $parentLoc->{'start_min'}) {
       $parentLoc->{'start_min'} = $start;
       $parentLoc->{'start_max'} = $start;
   }

   if ($end > $parentLoc->{'end_max'}) {
       $parentLoc->{'end_min'} = $end;
       $parentLoc->{'end_max'} = $end;
   }

return $parentLoc;
}



sub buildPredictedAAFeature{
    my ($self,$match,$gusAASeq) = @_;

return 1;
}


sub buildInterproMatch {
    my ($self,$match,$aaId) = @_;

    my $id = $match->att('id');
    my $name = $match->att('name');
    my $type = $match->att('type');
    my $iprVer = $self->{'iprDataVer'};

    my $gusDom = GUS::Model::DoTS::DomainFeature->new({ 'name' => $name,
                                                        'source_id' => $id,
                                                        'is_predicted' => 1,
                                                        'external_database_release_id' => $iprVer,
                                                        'aa_sequence_id' => $aaId,
                                                        'description' => $type, });
    my $parentLoc = { 'start_min' => 100000,
                      'start_max' => 100000,
                      'end_min' => 0,
                      'end_max' => 0 };

    my $eltn = 1;
    while (my $location = $match->next_n_elt($eltn)) {
       if ($location->tag() eq 'location') {
            my $start = $location->att('start');
            my $end = $location->att('end');
            $parentLoc = $self->updateParentLoc($parentLoc,$start,$end); 
       }
    $eltn++;
    }

    my $loc = GUS::Model::DoTS::AALocation->new($parentLoc);
    $gusDom->addChild($loc);
 
return $gusDom;
}


sub buildClassification {
    my ($self, $aaId, $classId) = @_;

     if ($classId =~ /^GO:\d+/) {
        my $goId = $self->getGOId($classId);
        my $evid = $self->getEvidenceCode('IEA');
        my $loe = $self->getOrCreateLOE('interpro results');
        my $asoc = $self->getOrCreateGOAssociation($goId,$aaId,$self->{'RefTableId'});
        my $goInstance = $self->getOrCreateGoInstance($asoc,$evid,$loe,'1');
     }
     else {
        print "Not a GO Id";
     }

return 1;

}



#############################################################################################
#Configuration and gus environment stuff
#############################################################################################
sub loadConfig{
  my ($self) = @_;
  
    $self->{'protCount'} = 0;
    $self->{'NewDBs'} = [];
    $self->{'NewAlgs'} = [];
    my $cFile = $self->getArgs()->{'confFile'} || die "No Conf File";
 
    $self->setIproVersions();

    my $queryTable = $self->getArgs()->{'queryTable'};
  
    unless ($queryTable eq 'ExternalAASequence' || 'TranslatedAASequence') {
        die "Not a valid query table";
    }

    my $gusRefTable = GUS::Model::Core::TableInfo->new({ 'name' => $queryTable });
    $gusRefTable->retrieveFromDB();
    $self->{'RefTableId'} = $gusRefTable->getId();

     $self->{'Predictions'}->{'transmembrane_regions'} = 'GUS::Model::DoTS::PredictedAAFeature';
     $self->{'Predictions'}->{'signal-peptide'} = 'GUS::Model::DoTS::SignalPeptideFeature';

     my $conf = $self->parseSimple($cFile);

     my $dbs = $conf->{'db'}; #list of Db names and versions

     my $iprDbs = $self->validateBootstrapping($dbs); #make sure all dbs are in GUS

     foreach my $db (keys %$iprDbs) {
        $self->{$db} = $iprDbs->{$db};
     }
    
     $self->validateInterproConfig(); #make sure all InterPro dbs are in config

     my $algs = $conf->{'alg'};
     $self->validateAlgs($algs);

return 1;
}

    
sub parseSimple{
  my ($self,$file) = @_;

  my $simple = XML::Simple->new();
  my $tree = $simple->XMLin($file, keyattr=>['name'], forcearray=>1);

return $tree;
}



sub setIproVersions {
    my $self = shift;

    my $iprAlg = $self->getArgs()->{'iprVer'};
    my $iprData = $self->getArgs()->{'iprDataVer'};

    my $gusAlg = GUS::Model::Core::Algorithm->new({ 'name' => 'iprscan',
                                            'description' => "irpscan ver. $iprAlg" });
       unless ($gusAlg->retrieveFromDB()) { $gusAlg->submit(); }
       my $gusAlgId = $gusAlg->getId();

    $self->{'iprVer'} = $gusAlgId;

    my $gusDb = GUS::Model::SRes::ExternalDatabase->new( { 'name' => 'Interpro', } );
       unless ($gusDb->retrieveFromDB()) { $gusDb->submit(); }
       my $gusDbId = $gusDb->getId();

    my $gusDbRls = GUS::Model::SRes::ExternalDatabaseRelease->new( { 'external_database_id' => $gusDbId,
                                                            'version' => $iprData, } );
       unless ($gusDbRls->retrieveFromDB()) { $gusDbRls->submit(); }
       my $gusDbRlsId = $gusDbRls->getId();

    $self->{'iprDataVer'} = $gusDbRlsId;

return 1;
}


sub validateBootstrapping {
    my ($self,$dbs) = @_;

    my $iprDbs = {};
    foreach my $db (keys %$dbs) {
        my $dbName = "$db (ipro)";
        my $dbVer = $dbs->{$db}->{'ver'};
        my $gusDbs = $self->sql_get_as_array("select b.external_database_release_id
                                        from sres.externaldatabase a, sres.externaldatabaserelease b
                                        where a.name=\'$dbName\' and b.version=\'$dbVer\'");
        my $relId = $gusDbs->[0];
        if ($relId eq '') { $relId = $self->handleNewDb($db,$dbVer) };
        $iprDbs->{$db} = $relId;
   }

return $iprDbs;
}


sub validateInterproConfig {
   my ($self,$dbs,$iprDbs) = @_;

    my $twig = XML::Twig->new( twig_roots => {
                               Header => validateHeaderDbs($self,$iprDbs),
                                             } );
    my $file = $self->getArgs()->{'resultFile'};
    $twig->parsefile($file);
    $twig->purge;
return 1;
}


sub validateHeaderDbs {
   my $self = shift;

   return sub {
    my $twig = shift;

    my $root = $twig->root();
    my $eltn = 1;
    while (my $elt = $root->next_n_elt($eltn, 'database')) {
        my $name = $elt->att('name');
        my $dbRls = $self->{$name};
            unless ($dbRls) { 
               die "$name : Database not in your configuration file.";
            }
    $eltn++;
    }
    $twig->purge();
   }
}



sub validateAlgs {
  my ($self, $algs) = @_;
     foreach my $alg (keys %$algs) {
        my $gusAlg = $self->sql_get_as_array ("select algorithm_id from core.algorithm
                                                   where name=\'$alg\'");
        my $algRelId = $gusAlg->[0];
        unless ($algRelId) {$algRelId = $self->handleNewAlg($alg,undef);}
        $self->{'Algorithms'}->{$alg} = $algRelId;
    }
return 1;
}


sub handleNewAlg {
    my ($self,$alg,$ver) = @_;

   unless ($self->getArgs()->{'bootData'}) {
     die "missing algorithm confiuration $alg: check sres.algorithm";
   }

   my $gusDb = GUS::Model::Core::Algorithm->new({ 'name' => $alg, });
   unless ($gusDb->retrieveFromDB()) { $gusDb->submit(); }
   my $gusDbId = $gusDb->getId();

   $self->{'Algorithms'}->{$alg} = $gusDbId;

push @{$self->{'NewAlgs'}}, $alg;

return $gusDbId;
}


sub handleNewDb {
   my ($self, $name, $ver) = @_;

   unless ($self->getArgs()->{'bootData'}) {
     die "missing database configuration $name: check sres.externaldatabase and config file";
   }

   my $gusDb = GUS::Model::SRes::ExternalDatabase->new({ 'name' => $name, });
   unless ($gusDb->retrieveFromDB()) { $gusDb->submit(); }
   my $gusDbId = $gusDb->getId();

   unless ($ver) { $ver = '0.0'; }   
   my $gusDbRel = GUS::Model::SRes::ExternalDatabaseRelease->new({ 'version' => $ver,
                                                     'external_database_id' => $gusDbId, });
   unless ($gusDbRel->retrieveFromDB()) {
      $gusDbRel->submit();
   }
   my $relId = $gusDbRel->getId();
   $self->{$name} = $relId;

push @{$self->{'NewDBs'}}, $name;

return $relId;
}


sub handleNewDbEntry {
#need to write this when we do ExtDbEntries
}


sub submitObjToGus {
   my ($self, $gusObj) = @_;

   unless ($gusObj->retrieveFromDB()) {
       eval { $gusObj->submit(); };
         if ($@) {
             $self->handleFailure($gusObj, $@);
             next;
         }
   }
return $gusObj;
}


sub handleFailure {
    my ($self, $A, $B);
    
    die "$B";
}

    
sub retSeqIdFromSrcId {
 my ($self,$featId) = @_;

    my $dbRlsId = $self->getExtDbRlsId($self->getArg('extDbName'),$self->getArg('extDbRlsVer'));
    my $gusTabl = GUS::Model::DoTS::TranslatedAASequence->new( {  #BIG ASSUMPTION - all seqs from TranslatedAASequence
                     'source_id' => $featId,
                     'external_database_release_id' => $dbRlsId,
                     } );

     $gusTabl->retrieveFromDB() || die ("Source Id $featId not found in TranslatedAASequence");
     my $seqId = $gusTabl->getId();

  return $seqId;
}


    
######GO
sub getGOId {
   my ($self, $goId) = @_;

   my $gusObj = GUS::Model::SRes::GOTerm->new( { 'go_id' => $goId, } );
   $gusObj->retrieveFromDB();
   my $gusId = $gusObj->getId();
      unless ($gusId) {
         my $altObj = GUS::Model::SRes::GOSynonym->new( { 'source_id' => $goId, } );
         $altObj->retrieveFromDB() || die "Go Term not found: $goId";
         $gusId = $altObj->getGoTermId();
      }

return $gusId;
}


sub getEvidenceCode {
    my ($self, $evidType) = @_;

    my $gusObj = GUS::Model::SRes::GOEvidenceCode->new( { 'name' => $evidType, } );
    $gusObj->retrieveFromDB() || die "No entry for the this evidence type";
    my $gusId = $gusObj->getId();
    
return $gusId;
}

sub getOrCreateLOE {
  my ($self, $loeName) = @_;

  my $gusObj = GUS::Model::DoTS::GOAssociationInstanceLOE->new( {
                         'name' => $loeName, } );

 unless ($gusObj->retrieveFromDB) { $gusObj->submit(); }
 my $loeId = $gusObj->getId();

return $loeId;
}


sub getOrCreateGOAssociation {
  my ($self, $goId, $aaId, $tableId) = @_;


     my $gusGOA = GUS::Model::DoTS::GOAssociation->new( {
                   'table_id' => $tableId,
                   'row_id' => $aaId,
                   'go_term_id' => $goId,
                   'is_not' => 0,
                   'is_deprecated' => 0,
                   'defining' => 0, } );
    unless ($gusGOA->retrieveFromDB()) {
       $gusGOA->submit(); 
    }
    my $goAssc = $gusGOA->getId();

return $goAssc;
}

sub deprecateGOInstances {
return 1;
}


sub getOrCreateGoInstance {
 my ($self, $asscId, $evidId, $loeId, $isPrim) = @_;  

 my $gusObj = GUS::Model::DoTS::GOAssociationInstance->new( {
                      'go_association_id' => $asscId,
                      'go_assoc_inst_loe_id' => $loeId,
                      'is_primary' => $isPrim,
                      'is_deprecated' => 0, } );
 
 unless ($gusObj->retrieveFromDB) { $gusObj->submit(); }
 my $instId = $gusObj->getId();

 my $evdObj = GUS::Model::DoTS::GOAssocInstEvidCode->new( {
                     'go_evidence_code_id' => $evidId,
                     'go_association_instance_id' => $instId, } );


 unless ($evdObj->retrieveFromDB) { $evdObj->submit(); }

return $instId;
}

    
1;

