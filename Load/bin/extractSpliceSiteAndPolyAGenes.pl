#!/usr/bin/perl

use strict;
use DBI;
use lib "$ENV{GUS_HOME}/lib/perl";
use CBIL::Util::PropertySet;
use Getopt::Long;
use ApiCommonData::Load::AnalysisConfigRepeatFinder qw(displayAndBaseName);
use File::Temp qw/ tempfile /;

my ($verbose,$gusConfigFile,$analysisConfigFile, $workingDir, $ssType, $extDbRlsSpec, $ties, @executableDirectory);

&GetOptions("verbose!" => \$verbose,
            "gusConfigFile=s" => \$gusConfigFile,
            "analysisConfigFile=s" => \$analysisConfigFile,
            "workingDir=s" => \$workingDir,
            "type=s" => \$ssType,
            'extDbRlsSpec=s' => \$extDbRlsSpec,
            'ties=s' => \$ties,
            'executable_path=s' => \@executableDirectory,

	    );

foreach(@executableDirectory) {
  $ENV{PATH} .= ":$_";
}

unless($ties eq "average" || $ties eq "first" || $ties eq "random" || $ties eq "max" || $ties eq "min") {
  die("Error:  ties must be specified as one of (average, first, random, max, or min)");
}


$gusConfigFile = $ENV{GUS_HOME} . "/config/gus.config" unless($gusConfigFile);

unless(-e $gusConfigFile) {
  die("gus.config file not found!")
}

unless(-e $analysisConfigFile) {
  die("config file $analysisConfigFile not found!");
}

unless($ssType eq 'Splice Site' || $ssType eq 'Poly A') {
  die "Type $ssType not allowed.  Should be [Splice Site] or [Poly A]";
}


my @properties = ();
my $gusconfig = CBIL::Util::PropertySet->new($gusConfigFile, \@properties, 1);

my $usr = $gusconfig->{props}->{databaseLogin};
my $pwd = $gusconfig->{props}->{databasePassword};
my $dsn = $gusconfig->{props}->{dbiDsn};

my $dbh = DBI->connect($dsn, $usr, $pwd) ||  die "Couldn't connect to database: " . DBI->errstr;
$dbh->{RaiseError} = 1;
$dbh->{AutoCommit} = 0;

my $table = $ssType eq 'Poly A' ? 'polyAgenes' : 'splicesitegenes';

my $analysisConfig = displayAndBaseName($analysisConfigFile);

my $sql = "
select ssg.source_id, sum(ssf.count_per_million)
from apidb.${table} ssg
 , APIDB.splicesitefeature ssf
 , study.protocolappnode pan
 , study.studylink sl
 , study.study s
 , sres.externaldatabaserelease r
 , SRES.externaldatabase d
where ssg.splice_site_feature_id = ssf.splice_site_feature_id
and ssf.protocol_app_node_id = pan.protocol_app_node_id
and pan.protocol_app_node_id = sl.protocol_app_node_id
and sl.study_id = s.study_id
and s.external_database_release_id = r.external_database_release_id
and r.external_database_id = d.external_database_id
and ssf.is_unique = 1
and pan.name = ?
and d.name || '|' || r.version = ?
and investigation_id is not null
group by ssg.source_id
";

my $sh = $dbh->prepare($sql);

foreach(keys %$analysisConfig) {
  my $hash = $analysisConfig->{$_};
  
  my $fileSuffix = "_profiles.txt";
  my $nodeSuffix = " [feature_loc] (SpliceSites)";

  die "Required one and exactly one sample" if scalar @{$hash->{samples}} != 1;

  my $protocolAppNodeName = $hash->{displayName} . $nodeSuffix;

  my $cleanSampleName = $hash->{displayName};
  $cleanSampleName =~ s/\s/_/g; 
  $cleanSampleName=~ s/[\(\)]//g;

  my $outputFile = $workingDir . "/" . $cleanSampleName . $fileSuffix;

  $sh->execute($protocolAppNodeName, $extDbRlsSpec);

  my ($tempFh, $tempFn) = tempfile();

  while(my ($gene, $count) = $sh->fetchrow_array()) {
    print $tempFh "$gene\t$count\n";
  }
  
  &addPercentileAndWriteOutput($tempFn, $outputFile, $ties);

  unlink($tempFn);
}


$dbh->disconnect();

sub addPercentileAndWriteOutput {
  my ($in, $out, $ties) = @_;

  my ($tempFh, $tempFn) = tempfile();

  my $header = "FALSE";

  my $rString = "
  source(\"$ENV{GUS_HOME}/lib/R/StudyAssayResults/profile_functions.R\");
  dat = read.table(\"$in\", header=$header, sep=\"\\t\", check.names=FALSE, row.names=1);
  pct = percentileMatrix(m=dat, ties=\"$ties\");
  output = cbind(rownames(dat), dat, pct);

  header=c(\"source_id\", \"value\", \"percentile_channel1\");
  cat(header,\"\\n\", file=\"$out\",sep=\"\\t\");
  write.table(output, file=\"$out\", quote=FALSE, sep=\"\\t\", row.names=FALSE, col.names=FALSE, append=TRUE);
  quit(\"no\");
";

      print $tempFh $rString;

  my $command = "cat $tempFn  | R --no-save ";

  my $systemResult = system($command);

  unless($systemResult / 256 == 0) {
    CBIL::StudyAssayResults::Error->new("Error while attempting to run R:\n$command")->throw();
  }

  unlink($tempFn);
}

1;
