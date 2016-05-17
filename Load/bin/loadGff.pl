#!/usr/bin/perl

# populate apidb.GeneGff from a GFF3 file

use strict;
use lib "$ENV{GUS_HOME}/lib/perl/";

use DBI;
use DBD::Oracle;
use Getopt::Long;
use File::Basename;

use CBIL::Util::PropertySet;

my ($gusConfigFile, $projectId, $inputFile, $tuningTablePrefix);
&GetOptions('gusConfigFile=s' => \$gusConfigFile,
            'projectId=s' => \$projectId,
            'inputFile=s' => \$inputFile,
    );

usage("required parameter missing")
  unless ($projectId && $inputFile);

if(!$gusConfigFile) {
  $gusConfigFile = $ENV{GUS_HOME} . "/config/gus.config";
}

usage("Config file $gusConfigFile does not exist.") unless -e $gusConfigFile;

my @properties;
my $gusconfig = CBIL::Util::PropertySet->new($gusConfigFile, \@properties, 1);

my $dbiDsn = $gusconfig->{props}->{dbiDsn};
my $dbiUser = $gusconfig->{props}->{databaseLogin};
my $dbiPswd = $gusconfig->{props}->{databasePassword};

my $dbh = DBI->connect($dbiDsn, $dbiUser, $dbiPswd) or die DBI->errstr;
$dbh->{RaiseError} = 1;
$dbh->{AutoCommit} = 0;

open(GFF, "<", $inputFile) or die "Cannot open file $inputFile for reading: $!";

my ($currentGene, $currentContent, $wdkTableId, $recordCount);

# get current max(wdk_table_id)
my $tableIdQ = $dbh->prepare(<<SQL) or die DBI->errstr;
   select nvl(max(wdk_table_id), 0) + 1
   from apidb.GeneGff
SQL

$tableIdQ->execute() or die DBI->errstr;
($wdkTableId) = $tableIdQ->fetchrow_array();
$tableIdQ->finish() or die DBI->errstr;

# prepare insert statement
my $insertStmt = $dbh->prepare(<<SQL) or die DBI->errstr;
   insert into apidb.GeneGff
     (wdk_table_id, source_id, project_id, table_name, row_count, content, modification_date)
   values (?, ?, '$projectId', 'gff_record', ?, ?, sysdate)
SQL

while (<GFF>) {

  # check for gene record
  if (/\tgene\t.*ID (\S*) /) {

    # write record for previous gene (if any)
    writeRecord($insertStmt, $currentGene, $currentContent, $wdkTableId++, $recordCount)
      if $currentGene;

    # reset info for next gene
    $currentGene = $1;
    $currentContent = "";
    $recordCount = 0;
  }

  $currentContent .= $_;
  $recordCount++;
}

# write record for final gene (unless there were none)
writeRecord($insertStmt, $currentGene, $currentContent, $wdkTableId++, $recordCount)
  if $currentGene;

print "done\n";

$dbh->disconnect();
close GFF;

1;

sub writeRecord {
  my ($insertStmt, $currentGene, $currentContent, $wdkTableId, $recordCount) = @_;

  # print "\n\nGFF record for gene \"$currentGene\":\n$currentContent\n";

  # ROW_COUNT column was always 1, not the number of file records
  $insertStmt->execute($wdkTableId, $currentGene, 1, $currentContent) or die DBI->errstr;

}

sub usage {

  my ($beef) = @_;

  print "usage: " . basename($0) . " -inputFile <GFF file> -projectId <projectId> [ -gusConfigFile <file> ]\n";
  die $beef;

}
