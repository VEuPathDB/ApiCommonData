package ApiCommonData::Load::Plugin::InsertInterproDomainDbs;
@ISA = qw(GUS::PluginMgr::Plugin);

use strict;

use DBI;
use Data::Dumper;
use XML::Simple;
use GUS::PluginMgr::Plugin;
use GUS::Model::Core::Algorithm;
use GUS::Model::SRes::ExternalDatabase;
use GUS::Model::SRes::ExternalDatabaseRelease;
use GUS::Model::SRes::ExternalDatabaseEntry;
use GUS::Model::DoTS::ExternalAASequence;


sub getArgsDeclaration {
my $argsDeclaration  =
[

fileArg({name => 'confFile',
         descr => 'File containing the domain database',
         constraintFunc=> undef,
         reqd  => 1,
         mustExist => 0,
         isList => 0,
         format=>'Text'
        }),

stringArg({name => 'iproVersion',
         descr => 'A valid version number',
         constraintFunc=> undef,
         reqd  => 1,
         isList => 0,
         format=>'Text'
        }),

fileArg({name => 'inPath',
         descr => 'user specified path to the directory containing all of the iprscan consitutent dbs.',
         constraintFunc=> undef,
         reqd  => 0,
         mustExist => 0,
         isList => 0,
         format=>'Text'
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
PURPOSE

my $purposeBrief = <<PURPOSEBRIEF;
PURPOSEBRIEF

my $syntax = <<SYNTAX;
SYNTAX

my $notes = <<NOTES;
NOTES

my $tablesAffected = <<AFFECT;
AFFECT

my $tablesDependedOn = <<TABD;
TABD

my $howToRestart = <<RESTART;
RESTART

my $failureCases = <<FAIL;
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

    my $dbs = $self->loadConfig();

     foreach my $db (@$dbs) {
        my $file = $self->{$db}->{'file'};
        my $rls = $self->{$db}->{'ver'};
        if ($file eq '') { $self->log("Warning: No file for $db: skipping");
                           next;
                         }

        my $subR = $self->{'SupportedDbs'}->{$db}; 

        if ($subR eq 'skip') {
            $self->log("Warning: NO CONFIGURATION FOR $db");
            next;
        }
        else {
           $self->log("Loading $db via $subR");
           my $eCount = $self->$subR($db,$file);
           $self->undefPointerCache();
           $self->log("$db:$eCount entries processed");
        }
     }
}



sub loadStandardFile { #prosite, uniprot, tigrfams, pfam
   my ($self, $name, $file) = @_;

   my $dataHash = {};
   my $eCount = 0;
   open STDRD, "$file" or die "No such file";
   while (<STDRD>) {
      if (/\/\//) {
         my $gusHash = $self->mapStandardDataValues($dataHash, $name);
         $self->submitGusEntry($gusHash);
         $eCount++;
      }
      elsif (/^([A-Z]+\s+)(.+)/) { 
        $dataHash->{substr($1,0,2)} = $2; 
     } 
   }
return $eCount;
}



sub mapStandardDataValues {
   my ($self, $dataHash, $name) = @_;

   if ($name eq 'PFAM' or $name eq 'TIGRFAMs') { $dataHash->{'ID'} = $dataHash->{'NA'}; }
      my $gusHash = { 'external_primary_identifier' => $dataHash->{'AC'},
 		      'external_secondary_identifier' => '',
                      'external_database_release_id' => $self->{$name}->{'ver'},
 		      'name' => $dataHash->{'ID'},
 		      'description' => $dataHash->{'DE'}, };

return $gusHash;
}


sub loadPrints{
   my ($self, $name, $file) = @_;

   my $eCount = 0;
   my $dataHash = {};
   open PRINTS, "<$file";
   while (<PRINTS>) {
      if (/gm\;/) {
         my $gusHash = $self->mapPrintsData($dataHash, $name);
         $self->submitGusEntry($gusHash);
         $eCount++;
      }
      my @dataAry = split(/\;/);
      $dataHash->{$dataAry[0]} = $dataAry[1];
   }
return $eCount;
}


sub mapPrintsData {
   my ($self, $dataHash, $name) = @_;

      my $gusHash = { 'external_primary_identifier' => $dataHash->{'gc'},
 		      'external_secondary_identifier' => $dataHash->{'gx'},
                      'external_database_release_id' => $self->{$name}->{'ver'},
 		      'name' => $dataHash->{'gc'},
 		      'description' => $dataHash->{'gi'}, };

return $gusHash;
}



sub loadGene3DCathFiles{
   my ($self, $name, $file) = @_;

   my $dataHash = {};
   my $eCount = 0;
   open DFILE, "<$file";
   while (<DFILE>) {
      if (/\/\//) {
         my $gusHash = $self->mapCathFileData($dataHash, $name);
         $self->submitGusEntry($gusHash);
         $dataHash = undef;
         $eCount++;
      }
         my @dataAry = split(/\t/);
         $dataHash->{@dataAry[0]} = $dataHash->{@dataAry[0]} . $dataAry[1];
   }
return $eCount;
}

 

sub mapCathFileData {
   my ($self, $dataHash, $name) = @_;

      my $gusHash = { 'external_primary_identifier' => $dataHash->{'CATHCODE'},
 		     'external_secondary_identifier' => $dataHash->{'DOMAIN'},
                    'external_database_release_id' => $self->{$name}->{'ver'},
 		     'name' => $dataHash->{'TOPOL'} . $dataHash->{'HOMOL'},
 		     'description' => $dataHash->{'NAME'}, };

return $gusHash;
}



sub loadProDom {
   my ($self, $name, $file) = @_;

#>Q9XYH6_CRYPV#PD000006#561#605 | 45 | pd_PD000006;sp_Q9XYH6_CRYPV_Q9XYH6; | (8753)  ATP-BINDING COMPLETE PROTEOME ABC TRANSPORTER TRANSPORTER COMPONENT ATPASE MEMBRANE SYSTEM
   open DFILE, "<$file";
   my $eCount = 0;
   while (<DFILE>) {
      my @dataAry = split(/\|/);
      my ($primId, $pdName) = split(/\;/,$dataAry[2]);
      my $gusHash = { 'external_primary_identifier' => substr($primId,4),
		      'external_secondary_identifier' => '',
                      'external_database_release_id' => $self->{$name}->{'ver'},
 		      'name' => substr($pdName,3),
 		      'description' => $dataAry[3], };
      if (/^>/) {
          $self->submitGusEntry($gusHash);
          $self->undefPointerCache();
          $eCount++;
      }
   }
return $eCount;
}



sub loadPanther {
   my ($self, $name, $file) = @_;

#PTHR11871       PROTEIN PHOSPHATASE PP2A REGULATORY SUBUNIT B   IPR000009       Protein phosphatase 2A regulatory subunit PR55
   my $eCount = 0;
   open DFILE, "<$file";
   while (<DFILE>) {
      my @dataAry = split(/\t/);
      my $gusHash = { 'external_primary_identifier' => "$dataAry[0]",
 		      'external_secondary_identifier' => $dataAry[2],
                      'external_database_release_id' => $self->{$name}->{'ver'},
 		      'name' => $dataAry[1],
 		      'description' => $dataAry[3], };
      $self->submitGusEntry($gusHash);
      $eCount++;
   }
return $eCount;
}


sub loadSuperfamily {
   my ($self, $name, $file) = @_;

#0024654 52540   c.37.1  d3adk__ P-loop containing nucleoside triphosphate hydrolases
   my $eCount = 0; 
   open DFILE, "<$file";
   while (<DFILE>) {
      my @dataAry = split(/\t/);
      my $gusHash = { 'external_primary_identifier' => "SSF$dataAry[1]",
 		      'external_secondary_identifier' => $dataAry[0],
                      'external_database_release_id' => $self->{$name}->{'ver'},
 		      'name' => $dataAry[2],
 		      'description' => $dataAry[4], };
      $self->submitGusEntry($gusHash);
      $eCount++;
   }
return $eCount;
}



sub loadPirsf {
   my ($self, $name, $file) = @_;

#   >PIRSF000002
#   Cytochrome c552
#   140.857142857143 12.7857807925909 18 260.571428571429 163.159285304124
#   BLAST: Yes
   my $gusHash = {};
   my @dataAry = undef;
   my $eCount = 0;
   open DFILE, "<$file";
   while (<DFILE>) {
      if (/^>(PIRSF[0-9]+)/) {
           if ($dataAry[1]) {
               my $gusHash = { 'external_primary_identifier' => $dataAry[1],
                             'external_secondary_identifier' => '',
                             'external_database_release_id' => $self->{$name}->{'ver'},
		             'name' => $dataAry[1],
    		             'description' => $dataAry[2], 
                             };
               $self->submitGusEntry($gusHash);
               $eCount++;
           }
           @dataAry = undef;
           push @dataAry, $1;
      } 
      else {
           push @dataAry;
      }
   }
return $eCount;
}


sub loadSmart {
   my ($self, $name, $file) = @_;

   my $eCount = 0; 
   open DFILE, "<$file";
   while (<DFILE>) {
      unless (/^\s\w/) {next;}
         chomp;
         s/\s+/ /g;
         my @dataAry = split(/\|/);  #name, def, desc
         my $gusHash = { 'external_primary_identifier' => $dataAry[0],
                         'external_secondary_identifier' => $dataAry[1],
                         'external_database_release_id' => $self->{$name}->{'ver'},
 		         'name' => $dataAry[0],
 		         'description' => $dataAry[2], };
      $self->submitGusEntry($gusHash);
      $eCount++;
   }
return $eCount;
}



sub submitGusEntry{
   my ($self, $gusHash) = @_;

   my $gusObj= GUS::Model::SRes::ExternalDatabaseEntry->new( $gusHash );
   unless ($gusObj->retrieveFromDB()) {
      $gusObj->submit();
   }

return 1;
}


sub loadConfig{
  my ($self) = @_;

     my $dbLst = [];
     my $cFile = $self->getArgs()->{'confFile'} || die "No Conf File";
     my $inPath = $self->getArgs()->{'inPath'};
     my $conf = $self->parseSimple($cFile);

     #List of DBs supported by this plugin
     $self->{'SupportedDbs'} = {
                  'PRODOM' => 'loadProDom',
                  'PIR' => 'loadPirsf',
                  'TIGRFAMs' => 'loadStandardFile',
                  'PROFILE' => 'loadStandardFile', 
                  'PANTHER' => 'loadPanther',
                  'PRINTS' => 'loadPrints',
                  'PROSITE' => 'loadStandardFile',
                  'UNIPROT' => 'loadStandardFile',
                  'PFAM' => 'loadStandardFile',
                  'SIGNALP' => 'skip',
                  'TMHMM' => 'skip',
                  'SMART' => 'loadSmart',
                  'GENE3D' => 'loadGene3DCathFiles',
                  'SUPERFAMILY' => 'loadSuperfamily',
                  } ;

     #InterPro Version Information
     my $iprVer = $self->getArgs()->{'iproVersion'};
     my $iprDbRls = $self->getOrLoadIprVer($iprVer);
     $self->log("Interpro $iprVer: $iprDbRls");
     
     #Configuration of DBs listed in Config File.
     my $dbs = $conf->{'db'};  
     foreach my $db (keys %$dbs) {
        my $rel = $dbs->{$db}->{'release'};
        my $ver = $dbs->{$db}->{'ver'};
        my $file = $dbs->{$db}->{'filename'};
        if ($inPath) {
          $file = "$inPath$file";
        }
           if ($iprVer ne $rel) {
              die "$db - $ver: Database release inconsistent with declared interpro version";
           }
           
        $self->log("Checking entry for external Db: $db $ver");

        my $gusDbRel = $self->getOrLoadDbs($db,$ver);

           if ($self->{'SupportedDbs'}->{$db} eq '') {
              die "$db: Not in plugins list of supported Dbs";
           }
           
        $self->{$db}->{'ver'} = $gusDbRel;
        $self->{$db}->{'file'} = $file;
        push @$dbLst, $db;
     }
     
     #Configuration of Algorithms listed in Config file.
     my $algs = $conf->{'alg'};
     foreach my $alg (keys %$algs) {
        my $iprAlgs = $self->getOrLoadAlgs($alg);
        $self->{$alg} = $iprAlgs;
     }

     $self->{'iprRls'} = $iprDbRls;

return $dbLst;
}

sub getOrLoadIprVer {
    my ($self, $iprVer) = @_;

    my $gusIpr = GUS::Model::SRes::ExternalDatabase->new( { 'name' => 'INTERPRO' } );
    unless ($gusIpr->retrieveFromDB() ) {
      $gusIpr->submit();
   }
    
    my $iprDb = $gusIpr->getId();
    my $gusIprVer = GUS::Model::SRes::ExternalDatabaseRelease->new( {
                                                             'external_database_id' => $iprDb,
                                                             'version' => $iprVer,
                                                               } );
    unless ($gusIprVer->retrieveFromDB() ) {
      $gusIprVer->submit();
    }
    my $iprDbVer = $gusIprVer->getId();

return $iprDbVer; 
}


sub getOrLoadDbs {
   my ($self, $name, $ver) = @_;

   my $relId;
   my $gusName = "$name (ipro)";
   my $gusDb = GUS::Model::SRes::ExternalDatabase->new({ 'name' => $gusName, });
   unless ($gusDb->retrieveFromDB()) {
      $gusDb->submit();
   }
   my $gusDbId = $gusDb->getId();
   my $iprVer = $self->getArgs()->{'iproVersion'};
   my $gusDesc = "$name version $ver data release from data/ for InterPro release number $iprVer";
   my $gusDbRel = GUS::Model::SRes::ExternalDatabaseRelease->new({ 'version' => $ver,
                                                     'description' => $gusDesc, 
                                                     'external_database_id' => $gusDbId, });
   unless ($gusDbRel->retrieveFromDB()) {
      $gusDbRel->submit();
   }

   $relId = $gusDbRel->getId();

return $relId;
}


sub getOrLoadAlgs {
   my ($self, $name) = @_;

   my $gusDb = GUS::Model::Core::Algorithm->new({ 'name' => $name, });
   unless ($gusDb->retrieveFromDB()) {
      $gusDb->submit();
   }
   my $algId = $gusDb->getId();

return $algId;
}


sub parseSimple{
  my ($self,$file) = @_;

  my $simple = XML::Simple->new();
  my $tree = $simple->XMLin($file, keyattr=>['name'], forcearray=>1);

return $tree;
}

1;

