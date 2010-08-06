#!/usr/bin/perl

use strict;
use Getopt::Long;
use IO::File;
use DBI;
use CBIL::Util::PropertySet;



#----Usage/Example----
# reformatChIP-ChipSmoothedProfiles.pl    --aefExtDbSpec 'name|version' --inputFile smoothedProfile
#---------------------
my ($aefExtDbSpec, $inputFile);
&GetOptions('aefExtDbSpec=s' => \$aefExtDbSpec,
            'inputFile=s' => \$inputFile,
           );

die "ERROR: Please provide a valid External Database Spec ('name|version') for the Array Element Features"  unless ($aefExtDbSpec);
die "ERROR: Please provide a valid smoothed profile file"  unless ($inputFile);

#------- Uid , Password and DSN ..these are fetched from the gus.config file----------

my $gusConfigFile = $ENV{GUS_HOME} . "/config/gus.config";

my @properties = ();
my $gusconfig = CBIL::Util::PropertySet->new($gusConfigFile, \@properties, 1);

my $u = $gusconfig->{props}->{databaseLogin};
my $pw = $gusconfig->{props}->{databasePassword};
my $dsn = $gusconfig->{props}->{dbiDsn};
my $dbh = DBI->connect($dsn, $u, $pw) or die DBI::errstr;
#----------------------------------------------------------------------

my $aefExtDbRlsId = getDbRlsId($aefExtDbSpec);

print("Processing input file.....\n");

my %profileHash;

open (IN, "$inputFile") or die "Cannot open file for reading:  $!";;

while (<IN>){
    chomp;
    next if /^\n/;
    my @arr = split (/\t/, $_);
    my ($mapStart, $mapEnd) = split (/-/,$arr[1]);
    my $key = $arr[0]."_".$mapStart;
    $profileHash{$key} = $arr[2];
}

print("Extracting Array Element Features.....\n");

my $aefSql = "select aef.source_id,
                     ns.source_id,
                     nl.start_min
              from   dots.arrayelementfeature aef, 
                     dots.nalocation nl,
                     dots.nasequence ns
              where  aef.na_feature_id = nl.na_feature_id 
              and    ns.na_sequence_id=aef.na_sequence_id
              and    aef.external_database_release_id = $aefExtDbRlsId";


my $sth = $dbh->prepare($aefSql);

$sth->execute || die "Could not execute SQL statement!";

while( my ($aefSourceId,$naSeqSourceId,$aefStartMin) = $sth->fetchrow_array() ){
    my $key=$naSeqSourceId."_".$aefStartMin;
    if ($profileHash{$key}){
	print "$aefSourceId\t$profileHash{$key}\n"
    }
} 


1;

sub getDbRlsId {

  my ($extDbRlsSpec) = @_;

  my ($extDbName, $extDbRlsVer) = &getExtDbInfo($extDbRlsSpec);

  my $stmt = $dbh->prepare("select dbr.external_database_release_id from sres.externaldatabaserelease dbr,sres.externaldatabase db where db.name = ? and db.external_database_id = dbr.external_database_id and dbr.version = ?");

  $stmt->execute($extDbName,$extDbRlsVer);

  my ($extDbRlsId) = $stmt->fetchrow_array();

  return $extDbRlsId;
}

sub getExtDbInfo {
  my ($extDbRlsSpec) = @_;
  if ($extDbRlsSpec =~ /(.+)\|(.+)/) {
    my $extDbName = $1;
    my $extDbRlsVer = $2;
    return ($extDbName, $extDbRlsVer);
  } else {
    die("Database specifier '$extDbRlsSpec' is not in 'name|version' format");
  }
}
