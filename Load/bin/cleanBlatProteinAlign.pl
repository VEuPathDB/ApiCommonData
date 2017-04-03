#!/usr/bin/perl

use strict;

use lib $ENV{GUS_HOME} . "/lib/perl";

use DBI;
use DBD::Oracle;

use GUS::Supported::GusConfig;

use Getopt::Long;

my ($help, $organismAbbrev, $gusConfig);

&GetOptions('organismAbbrev=s' => \$organismAbbrev,
            'gusConfig=s' => \$gusConfig
    );


unless($organismAbbrev) {
  die "usage:  cleanBlatProteinAlign.pl --organismAbbrev=s [--gusConfig=s]";
}

$gusConfig = "$ENV{GUS_HOME}/config/gus.config" unless($gusConfig);

unless(-e $gusConfig) {
  die "Config file $gusConfig does not exist.";
}

my $totalTime;
my $totalTimeStart = time();

my $config = GUS::Supported::GusConfig->new($gusConfig);

my $login       = $config->getDatabaseLogin();
my $password    = $config->getDatabasePassword();
my $dbiDsn      = $config->getDbiDsn();

my $dbh = DBI->connect($dbiDsn, $login, $password) or die DBI->errstr;
$dbh->{RaiseError} = 1;
$dbh->{AutoCommit} = 0;

my $locSql = "select distinct ba.target_na_sequence_id from apidb.blatproteinalignment ba, apidb.organism o where ba.target_taxon_id = o.taxon_id and o.abbrev = ?";
my $locSh = $dbh->prepare($locSql);
$locSh->execute($organismAbbrev);

my $sql = "select blat_protein_alignment_id, target_start, target_end, score, query_bases_aligned  from apidb.BLATPROTEINALIGNMENT where TARGET_NA_SEQUENCE_ID = ? order by target_start asc, target_end asc, score desc, query_bases_aligned desc";
my $sh = $dbh->prepare($sql);


while(my ($naSeqId) = $locSh->fetchrow_array()) {
  $sh->execute($naSeqId);

  my @features;
  my %positions;
  my %keepers;

  my $seqTotalTime;
  my $seqTotalTimeStart = time();

  my ($prevStart, $prevEnd, $prevFeature);
  my $bAlignCt;

  while(my ($blatProteinAlignmentId, $start, $end, $score, $basesAligned) = $sh->fetchrow_array()) {
    $keepers{$blatProteinAlignmentId} = 0;

    next if(($end - $start) > 5000);

    if($start == $prevStart && $end == $prevEnd) {
      next if($bAlignCt++ > 10);

      push @{$prevFeature->{_id_and_scores}}, [$blatProteinAlignmentId, $score, $basesAligned];
      next;
    } 

    $bAlignCt = 1;

    my $feature = {start => $start, 
                   end => $end,
    };

    push @{$feature->{_id_and_scores}}, [$blatProteinAlignmentId, $score, $basesAligned];

    push @features, $feature;

    $positions{$start}++;
    $positions{$end+1}++; # need a +1 on the end position

    $prevStart = $start;
    $prevEnd = $end;
    $prevFeature = $feature;
  }
  my $loggerCount = 1;

  my @sortedPositions = sort {$a <=> $b} keys(%positions);

  for(my $i = 0; $i < scalar(@sortedPositions)-1; $i++) {

    my $loc = $sortedPositions[$i];

    my $index = 0;
    my @keep;

    while(1) {
      last unless($features[$index]);

      if($features[$index]->{start} > $loc) {
        last;
      }
      
      if($features[$index]->{end} >= $loc) {
        push @keep, $features[$index];
      }
      
      if($features[$index]->{end} < $loc) {
        splice(@features, $index, 1);
      }
      else {
        $index++; 
      }
    }

    my @expanded;
    foreach(@keep) {
      push @expanded, @{$_->{_id_and_scores}};
    }

    my @sorted = sort {$b->[1] <=> $a->[1] || $b->[2] <=> $a->[2] } @expanded;

    my $count = 1;
    foreach(@sorted) {
      my $blatId = $_->[0];
       
      $keepers{$blatId} = 1;

      $count++;
      last if($count > 10);
    }
  }

  my $countKeep;

  my @deletes;
  my $deleteCount = 0;

  my $countBlatAligns = scalar(keys(%keepers));

  my $commitCount = 0;

  foreach my $blatId (keys %keepers) {
    if($keepers{$blatId}) {
      $countKeep++;
    }
    else {
      push @deletes, $blatId;
      $deleteCount++;

      if($deleteCount == 1000) {
        my $deleteIds = join(',', @deletes);
        my $deleteSql = "delete apidb.blatproteinalignment where blat_protein_alignment_id in ($deleteIds)";
        my $deleteSh = $dbh->do($deleteSql);

        @deletes = ();
        $deleteCount = 0;


        if(++$commitCount % 10 == 0) {
          $dbh->commit();
          $commitCount = 0;
        }
      }

    }
  }

  if(scalar @deletes > 0) {
    my $deleteIds = join(',', @deletes);
    my $deleteSql = "delete apidb.blatproteinalignment where blat_protein_alignment_id in ($deleteIds)";
    my $deleteSh = $dbh->do($deleteSql);
    $dbh->commit();
  }

  $seqTotalTime += time() - $seqTotalTimeStart;
  my $countDiscard = $countBlatAligns - $countKeep;

  print STDERR "Took $seqTotalTime Seconds to keep $countKeep and discard $countDiscard for na_sequence_id $naSeqId\n";
}


$dbh->disconnect();

$totalTime += time() - $totalTimeStart;
print STDERR "Took $totalTime Seconds to process organism $organismAbbrev\n";

1;




