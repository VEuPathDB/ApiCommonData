#!/usr/bin/perl
use strict;
use lib "$ENV{GUS_HOME}/lib/perl";
use Getopt::Long;
use GUS::ObjRelP::DbiDatabase;
use GUS::Supported::GusConfig;

my ($RNASeqExtDbSpecs,$genomeExtDbSpecs,$sample,$filename, $verbose);
&GetOptions("RNASeqExtDbSpecs|s=s" => \$RNASeqExtDbSpecs,
	    "genomeExtDbSpecs|s=s" => \$genomeExtDbSpecs,
            "sample|t=s" => \$sample,
            "filename|mf=s" => \$filename,
            );

die "usage: generateCoveragePlotInputFile.pl 
      --filename|f <filename> 
      --RNASeqExtDbSpecs|s <Db Specs for experiment (required)> 
      --genomeExtDbSpecs|s <Db Specs for genome (required)> 
      --sample <sample name (required)> " unless $RNASeqExtDbSpecs && $sample && $filename && $genomeExtDbSpecs ;

#=======================================================================

my $gusConfigFile = $ENV{GUS_HOME} . "/config/gus.config";
my $gusconfig = GUS::Supported::GusConfig->new($gusConfigFile);

my $db = GUS::ObjRelP::DbiDatabase->new($gusconfig->getDbiDsn(),
                                        $gusconfig->getDatabaseLogin(),
                                        $gusconfig->getDatabasePassword(),
                                        $verbose,0,1,
                                        $gusconfig->getCoreSchemaName());

my $dbh = $db->getQueryHandle();

my $RNASeqExtDbRlsId = &getExtDbRlsId($RNASeqExtDbSpecs);
my $genomeExtDbRlsId = &getExtDbRlsId($genomeExtDbSpecs);
my $sqlSeq = "select na_sequence_id, source_id from dots.NASEQUENCE where external_database_release_id = '$genomeExtDbRlsId'";
my %naSeqHash;
my $sth = $dbh->prepareAndExecute($sqlSeq);
while (my ($na_seuqnce_id , $source_id) = $sth->fetchrow_array()) {
    $naSeqHash{$source_id} = $na_seuqnce_id;
}
$sth->finish();
$dbh->disconnect();

 open(F,"$filename") || die "unable to open $filename\n";
  
  while(<F>){
    next if (/^track/);
    chomp;
    my ($source_id,$location,$coverage) = split("\t",$_);

    if($naSeqHash{$source_id}){
	print "$RNASeqExtDbRlsId\t$sample\t$naSeqHash{$source_id}\t$location\t$location\t$coverage\t\t\n";
    }
  }
  close F;

sub getExtDbRlsId {
    my($extDbSpecs) = @_;
    my ($extDbName,$extDbRlsVer)=split(/\|/,$extDbSpecs);
    my $sql = "select external_database_release_id from sres.externaldatabaserelease d, sres.externaldatabase x where x.name = '${extDbName}' and x.external_database_id = d.external_database_id and d.version = '${extDbRlsVer}'";
    my $sth = $dbh->prepareAndExecute($sql);
    my $extDbRlsId = $sth->fetchrow_array();
    $sth->finish();
    return $extDbRlsId;
}


