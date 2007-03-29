package ApiCommonData::Load::Plugin::InsertInterproDomainDbs;
@ISA = qw(GUS::PluginMgr::Plugin);

use strict;

use DBI;
use Data::Dumper;
use XML::Simple;
use GUS::PluginMgr::Plugin;
use GUS::Model::SRes::ExternalDatabase;
use GUS::Model::SRes::ExternalDatabaseRelease;
use GUS::Model::SRes::DbRef;
use Data::Dumper;

# Notes:
#	1. confFile is NOT validated for XML. If there is an error in the XML file, the program simply quits, 
#		without any warning or failure messages.
#	2. Supports testnumber command-line argument, which is applied to each database defined in the confFile. 
#		Use it for testing, as the processing could take a long time.
#	3. The statusCountsByDb is used in reporting the status for every n items processed. 




sub getArgsDeclaration {
my $argsDeclaration  =
[

fileArg({name => 'inPath',
         descr => 'user specified path to the directory containing all of the iprscan consitutent dbs and the config file for this plugin (named insertInterpro-config.xml',
         constraintFunc=> undef,
         reqd  => 1,
         mustExist => 0,
         isList => 0,
         format=>'Text'
        }),

 integerArg({name  => 'testnumber',
	     descr => 'Number of query sequences to process for testing',
	     reqd  => 0,
	     constraintFunc=> undef,
	     isList=> 0,
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
The config file is in the data directory and is call insertInterpro-config.xml.
It looks like this:
<configuration>
	<!-- Refers to Interpro 12.1. Change as necessary -->
   <db name="PRODOM" release="4.2" filename="prodom.ipr" ver="2004.1" format="PRODOM" logFreq="1000"/>
    etc...

</configuration>

the <db> tags describe the member databases. the attributes are:
  name:     the name of the resource (goes into ExternalDatabase.name)
  release:  the interpro release
  filename: the basename of the file that contains the member database
  ver:      the version of the member database (goes into ExternalDatabaseRelease.version)
  format:   the file format.  see the code for supported formats (or add one if you need to)
  logFreq:  how often to log progress, ie, after processing how many motifs.

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

my $SUPPORTED_FORMATS =
  {
   'HMM' => 'loadHMMFormat',
   'PRODOM' => 'loadProdomFormat',
   'PIR' => 'loadPirsfFormat',
   'PRF' => 'loadPRFFormat',
   'PRINTS' => 'loadPrintsFormat',
   'PROSITE' => 'loadPrositeFormat',
   'INTERPRO' => 'loadInterproFormat',
   'SUPERFAMILY' => 'loadSuperfamilyFormat'
  } ;

sub run {
  my $self = shift;

  my $dbCount = 0;
  my $dbs = $self->loadConfig();

  foreach my $db (@$dbs) {
    my $subR = $SUPPORTED_FORMATS->{$self->{$db}->{format}};
    $self->log("Loading $db ($self->{$db}->{format} format)");
    my $eCount = $self->$subR($db, $self->{$db}->{filename},
			      $self->{$db}->{logFreq});
    $self->{stats}->{$db} = $eCount;
    $self->log("  $db: $eCount");
    $dbCount++;
  }
  foreach my $db (@$dbs) {
    $self->log("Summary", "$db: $self->{stats}->{$db}");
  }
  return "Completed loading $dbCount databases.";
}


sub loadHMMFormat {
   my ($self, $dbName, $file, $logFreq) = @_;
   $self->loadHMMFormat_aux($dbName, $file, $logFreq, 'NA');
}

sub loadPRFFormat {
   my ($self, $dbName, $file, $logFreq) = @_;
   $self->loadHMMFormat_aux($dbName, $file, $logFreq, 'ID');
}


#HMMER2.0
#ACC   SM00101
#NAME  14_3_3
#DESC  ADP-LIKE TRANSPORTER
#LENG  249
#...
#//
sub loadHMMFormat {
   my ($self, $dbName, $file, $logFreq) = @_;
   my $testNum = $self->getArgs()->{'testnumber'};
   my $dataHash = {};
   my %seen;
   my $eCount = 0;
   open (DFILE, $file);
   while (<DFILE>) {
     chomp;
     if (/^\/\//) {
       $dataHash->{ACC} =~ s/\.\d+\.(?:fs|ls)$// if $dbName eq 'PFAM';  # lose any version info (eg, PF00032.1.fs)
       next if $seen{$dataHash->{ACC}}++;
       $self->submitDbRef($dbName, $dataHash->{ACC}, $dataHash->{NAME},
			  $dataHash->{DESC}, $logFreq, ++$eCount);
     }
     elsif (/^(ACC|NAME|DESC)\s+(.+)/) {
       my $key = $1;
       my $val = $2;
       $dataHash->{$key} = $val;
     }

     last if ($testNum && $eCount >= $testNum);
   }
   close(DFILE);
   return $eCount;
}
#ID   HSP20; MATRIX.
#AC   PS01031;
#DT   JUN-1994 (CREATED); DEC-2001 (DATA UPDATE); SEP-2005 (INFO UPDATE).
#DE   Heat shock hsp20 proteins family profile.
#MA   /GENERAL_SPEC: ALPHABET='ABCDEFGHIKLMNPQRSTVWYZ'; LENGTH=88;

sub loadPRFFormat {
   my ($self, $dbName, $file, $logFreq) = @_;
   my $testNum = $self->getArgs()->{'testnumber'};
   my $dataHash = {};
   my %seen;
   my $eCount = 0;
   open (DFILE, $file);
   while (<DFILE>) {
     chomp;  # trailing newline
     if (/^\/\//) {
       next if !$dataHash->{AC} or $seen{$dataHash->{AC}}++;
       $self->submitDbRef($dbName, $dataHash->{AC}, $dataHash->{ID},
			  $dataHash->{DE}, $logFreq, ++$eCount);
     }
     elsif (my ($k, $v) = /^(AC|ID|DE)\s+(.+)/) {
       $dataHash->{$k} = $v;
       $dataHash->{$k} =~ s/[\.;]+$//;   # trailing punctuation
       $dataHash->{$k} =~ s/;\s+(?:MATRIX|PATTERN)$// if ($k eq 'ID');
     }

     last if ($testNum && $eCount >= $testNum);
   }
   close(DFILE);
   return $eCount;
}

# PS00010 C.[DN]....[FY].C.C ASX_HYDROXYL ??E??
sub loadPrositeFormat {
   my ($self, $dbName, $file, $logFreq) = @_;
   my $testNum = $self->getArgs()->{'testnumber'};

   open DFILE, "<$file";
   my $eCount = 0;

   while (<DFILE>) {
     my @dataAry = split(/\s+/);
     $self->submitDbRef($dbName, $dataAry[0], $dataAry[2], undef, $logFreq, ++$eCount);
     last if ($testNum && $eCount >= $testNum);
   }
   close(DFILE);

   return $eCount;
}

#gc; 11SGLOBULIN
#gx; PR00439
#gn; 7
#gi; 11-S seed storage protein family signature
#gm; 74
sub loadPrintsFormat {
   my ($self, $dbName, $file, $logFreq) = @_;

   my $testNum = $self->getArgs()->{'testnumber'};

   my $eCount = 0;
   my $dataHash = {};
   open PRINTS, "<$file";
   while (<PRINTS>) {
     chomp;
     if (/^gm/) {
       $self->submitDbRef($dbName, $dataHash->{gx}, $dataHash->{gc}, $dataHash->{gi}, $logFreq, ++$eCount);
     }
     elsif (/^(gc|gx|gi)\;\s+(.+)/) {
       $dataHash->{$1} = $2;
     }
     last if ($testNum && $eCount >= $testNum);
   }
   close(PRINTS);
   return $eCount;
}

#>Q9XYH6_CRYPV#PD000006#561#605 | 45 | pd_PD000006;sp_Q9XYH6_CRYPV_Q9XYH6; | (8753)  ATP-BINDING COMPLETE PROTEOME ABC TRANSPORTER TRANSPORTER COMPONENT ATPASE MEMBRANE SYSTEM
#NLSGGQKQRVSLARAVYQNTDILILDDVFSALDNVVSTSIFQKCI
sub loadProdomFormat {
   my ($self, $dbName, $file, $logFreq) = @_;
   my $testNum = $self->getArgs()->{'testnumber'};
   open DFILE, "<$file";
   my $eCount = 0;
   my %seen;
   while (<DFILE>) {
     next unless /^>/;
     chomp;
     my @dataAry = split(/\|/);
     my ($junk, $primId, $junk2) = split(/\#/, $dataAry[0]);
     next if $seen{$primId}++;
     my ($junk3, $desc) = split(/\)\s+/, $dataAry[3]);
     $desc =~ s/\s+$//;   # lose trailing white space
     $self->submitDbRef($dbName, $primId, undef, $desc, $logFreq, ++$eCount);
     last if ($testNum && $eCount >= $testNum);
   }

   close(DFILE);
   return $eCount;
}


#>PIRSF000002
#Cytochrome c552     (note:  this field gets quite long, eg > 100)
#140.857142857143 12.7857807925909 18 260.571428571429 163.159285304124
#BLAST: Yes
sub loadPirsfFormat {
   my ($self, $dbName, $file, $logFreq) = @_;

   my $testNum = $self->getArgs()->{'testnumber'};
   my $eCount = 0;
   open DFILE, "<$file";
   my $id;
   my $getDescNext;
   my $desc;
   while (<DFILE>) {
     chomp;
     if (/^>(\w+)/) {
       $id = $1;
       $getDescNext = 1;
     } elsif ($getDescNext) {
       $getDescNext = 0;
       $desc = $_;
       $self->submitDbRef($dbName, $id, undef, $desc, $logFreq, ++$eCount);
       last if ($testNum && $eCount >= $testNum)
     }
   }
   close(DFILE);
   return $eCount;
}


#<interpro id="IPR000001" type="Domain" short_name="Kringle" protein_count="303">
#    <name>Kringle</name>
sub loadInterproFormat {
   my ($self, $dbName, $file, $logFreq) = @_;

   my $testNum = $self->getArgs()->{'testnumber'};
   my $eCount = 0;
   open(DFILE,$file);
   my $id;
   my $name;
   my $desc;
   while (<DFILE>) {
     if (/^\s*\<interpro id="(\w+)".+short_name="(.*)" protein_count/) {
       $id = $1;
       $name = $2
     } elsif (/\<name\>(.*)\</) {
       $desc = $1;
       $self->submitDbRef($dbName, $id, $name, undef, $logFreq, ++$eCount);
       last if ($testNum && $eCount >= $testNum)
     }
   }
   close(DFILE);
   return $eCount;
}

#0016282 SSF54076        d.5.1   d11bga_ RNase A-like
#
# The superfamily.tab file bundled with the Interproscan data does not have the
# "SSF" prefix seen above. This change is needed to ensure consistency between superfamily ids, 
# and interproscan results.
# 
# The script to make this change is in the <unpack> section of plasmoResources.xml: 
# <unpack>cat @downloadDir@/InterproscanData/12.1/iprscan/data/superfamily.tab | tr "\t" ":" | awk -F: '{ ssfid = sprintf ("SSF%s", $2); printf "%s\t%s\t%s\t%s\t%s\n", $1, ssfid, $3, $4, $5}' > @downloadDir@/InterproscanData/12.1/iprscan/data/superfamily-fixed.tab</unpack>
# 

sub loadSuperfamilyFormat {
	my ($self, $dbName, $file, $logFreq) = @_;

	my $testNum = $self->getArgs()->{'testnumber'};
	my $eCount = 0;
	open (DFILE, "< $file");
	my $line;
	while ($line = <DFILE>) {
		$line =~ s/\s+$//;
		my ($acc, $id, $scopclass, $junk, $desc) = split (/\t/, $line);
		$self->submitDbRef ($dbName, $id, $acc, $desc, $logFreq, ++$eCount);

		last if ($testNum && $eCount >= $testNum);
	}

	close DFILE;
	return $eCount;
}


sub submitDbRef{
   my ($self, $dbName, $id, $name, $descr, $logFreq, $eCount) = @_;
   
   map { $_ =~ s/^\s+//; $_ =~ s/\s+$//; } ($id, $name);

   warn "'$dbName', '$id', '$name', '$descr'\n" if $self->getArgs()->{'veryVerbose'};

   my $gusHash = { 'primary_identifier' => $id,
		   'secondary_identifier' => $name,
		   'external_database_release_id' => $self->{$dbName}->{extDbRlsId},
		   'remark' => $descr };

   my $gusObj= GUS::Model::SRes::DbRef->new( $gusHash );
   $gusObj->submit();
   $self->undefPointerCache() if $eCount % 1000 == 0;
   $self->log("   $eCount") if $eCount % $logFreq == 0;
}


sub loadConfig{
  my ($self) = @_;

  my $inPath = $self->getArg('inPath');
  my $cFile = "$inPath/insertInterpro-config.xml";
  $self->error("Can't open config file '$cFile'")
    unless (-r $cFile && -f $cFile);

  my $conf = $self->parseSimple($cFile);

  #Configuration of DBs listed in Config File.
  my $dbs = $conf->{'db'};
  my @dbNames;
  foreach my $dbName (keys %$dbs) {
    $self->{$dbName} = $dbs->{$dbName};
    my $ver = $self->{$dbName}->{ver};
    my $file = $self->{$dbName}->{filename} = 
      "$inPath/$self->{$dbName}->{filename}";
    my $format = $self->{$dbName}->{format};
    my $logFreq = $self->{$dbName}->{logFreq};
    if (!$SUPPORTED_FORMATS->{$format}) {
      die "Format '$format' (used by db: '$dbName') is not supported";
    }

    $self->error("input file '$file' for database '$dbName' cannot be opened")
      unless (-r $file && -f $file);

    $self->log("Checking entry for external Db: $dbName $ver");

    $self->{$dbName}->{extDbRlsId} = $self->getOrLoadDbs($dbName, $ver);

    push(@dbNames, $dbName);
  }

  return \@dbNames;
}

sub parseSimple{
  my ($self,$file) = @_;

  my $simple = XML::Simple->new();
  my $tree = $simple->XMLin($file, keyattr=>['name'], forcearray=>1);

  return $tree;
}

sub getOrLoadDbs {
  my ($self, $dbName, $ver) = @_;

  my $gusDb = GUS::Model::SRes::ExternalDatabase->new({ 'name' => $dbName, });
  unless ($gusDb->retrieveFromDB()) {
    $gusDb->submit();
  }

  my $gusDbRel = 
    GUS::Model::SRes::ExternalDatabaseRelease->
	new({ 'version' => $ver,
	      'external_database_id' => $gusDb->getId() });

  unless ($gusDbRel->retrieveFromDB()) {
    $gusDbRel->submit();
  }

  return $gusDbRel->getId();
}

sub undoTables {
  my ($self) = @_;

  return (
		'SRes.DbRef',
  		'SRes.ExternalDatabaseRelease',
		'SRes.ExternalDatabase'
     );
}

1;

