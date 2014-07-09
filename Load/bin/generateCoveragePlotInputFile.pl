#!/usr/bin/perl
#vvvvvvvvvvvvvvvvvvvvvvvvv GUS4_STATUS vvvvvvvvvvvvvvvvvvvvvvvvv
  # GUS4_STATUS | SRes.OntologyTerm              | auto   | absent
  # GUS4_STATUS | SRes.SequenceOntology          | auto   | absent
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
die 'This file has broken or unreviewed GUS4_STATUS rules.  Please remove this line when all are fixed or absent';
#^^^^^^^^^^^^^^^^^^^^^^^^^ End GUS4_STATUS ^^^^^^^^^^^^^^^^^^^^
use strict;
use lib "$ENV{GUS_HOME}/lib/perl";
use Getopt::Long;
use GUS::ObjRelP::DbiDatabase;
use GUS::Supported::GusConfig;

my ($RNASeqExtDbSpecs,$genomeExtDbSpecs,$sample,$filename, $multiple,$verbose);
&GetOptions("RNASeqExtDbSpecs|s=s" => \$RNASeqExtDbSpecs,
	    "genomeExtDbSpecs|s=s" => \$genomeExtDbSpecs,
            "sample|t=s" => \$sample,
            "multiple|t=s" => \$multiple,
            "filename|mf=s" => \$filename,
            );

die "usage: generateCoveragePlotInputFile.pl 
      --filename|f <filename> 
      --RNASeqExtDbSpecs|s <Db Specs for experiment (required)> 
      --genomeExtDbSpecs|s <Db Specs for genome (required)> 
      --sample <sample name (required)> 
      --multiple <unique mappings or non-unique mappings (required)>" unless $RNASeqExtDbSpecs && $sample && $filename && $genomeExtDbSpecs && $multiple;

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
my $sqlSeq = "select na_sequence_id, source_id from dots.NASEQUENCE";
my %naSeqHash;
my $sth = $dbh->prepareAndExecute($sqlSeq);
while (my ($na_sequence_id , $source_id) = $sth->fetchrow_array()) {
    $naSeqHash{$source_id} = $na_sequence_id;
}
$sth->finish();
$dbh->disconnect();

 open(F,"$filename") || die "unable to open $filename\n";
  my $multipleVal;
  if (lc $multiple eq 'false'){
      $multipleVal= 0;
  }else{
      $multipleVal= 1;
  }
  
  while(<F>){
    next if (/^track/);
    chomp;
    my ($source_id,$start,$end,$coverage) = split("\t",$_);

    die "Can't reformat coverage plot file, values missing:\n $RNASeqExtDbRlsId\t$sample\t$naSeqHash{$source_id}\t$start\t$end\t$coverage\t$multipleVal" unless ($source_id && ($start || $start == 0 ) && $end &&$coverage);

    if($naSeqHash{$source_id}){
	print "$RNASeqExtDbRlsId\t$sample\t$naSeqHash{$source_id}\t$start\t$end\t$coverage\t$multipleVal\t\n";
    }
    else {
      die "Can't find na_sequence_id for source_id = $source_id\n";
    }
  }
  close F;

sub getExtDbRlsId {
    my($extDbSpecs) = @_;
    my ($extDbName,$extDbRlsVer)=split(/\|/,$extDbSpecs);
    my $sql = "select external_database_release_id from sres.externaldatabaserelease d, sres.externaldatabase x where x.name = '${extDbName}' and x.external_database_id = d.external_database_id and d.version = '${extDbRlsVer}'";
    my $sth = $dbh->prepareAndExecute($sql);
    my $extDbRlsId = $sth->fetchrow_array();
    die "Can't retrieve an ext db rls id with $extDbSpecs" unless $extDbRlsId;

    $sth->finish();
    return $extDbRlsId;
}


