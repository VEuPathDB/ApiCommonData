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

my $sql = "select blat_protein_alignment_id, target_start, target_end, score, query_bases_aligned  from APIDB.BLATPROTEINALIGNMENT where TARGET_NA_SEQUENCE_ID = ? and (target_end - target_start) < 5000 order by target_start asc, target_end asc, score desc, query_bases_aligned desc";
my $sh = $dbh->prepare($sql);

my $deleteSql = "delete apidb.blatproteinalignment where blat_protein_alignment_id = ?";
my $deleteSh = $dbh->prepare($deleteSql);

while(my ($naSeqId) = $locSh->fetchrow_array()) {
  $sh->execute($naSeqId);

  my @features;
  my %positions;
  my %keepers;

  print STDERR "WORKING ON NASEQUENCE $naSeqId\n";

  my ($prevStart, $prevEnd, $prevFeature);

  while(my ($blatProteinAlignmentId, $start, $end, $score, $basesAligned) = $sh->fetchrow_array()) {
    $keepers{$blatProteinAlignmentId} = 0;

    if($start == $prevStart && $end == $prevEnd) {
      push @{$prevFeature->{_id_and_scores}}, [$blatProteinAlignmentId, $score, $basesAligned];
      next;
    } 

    my $feature = {start => $start, 
                   end => $end
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

  print STDERR "Begin Processing Distinct locations\n";

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

      if($index == 0 && $features[$index]->{end} < $loc) {
        shift @features;
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

#    print STDERR "Found " . scalar @sorted . " Features which overlap location $loc\n";

    my $count = 1;
    foreach(@sorted) {
      my $blatId = $_->[0];
       
      $keepers{$blatId} = 1;

      $count++;
      last if($count > 10);
    }
    
    if($loggerCount++ % 1000 == 0) {
      print STDERR "Processed $loggerCount positions for na sequence $naSeqId\n";
     }

  }

  my ($countKeep, $countDiscard);
  foreach my $blatId (keys %keepers) {

    if($keepers{$blatId}) {
      $countKeep++;
    }
    else {
      $deleteSh->execute($blatId);
      $dbh->commit();
      $countDiscard++;
    }
  }

  print STDERR "KEEP $countKeep for na_sequence_id $naSeqId\n";
  print STDERR "DISCARDED $countDiscard for na_sequence_id $naSeqId\n";
}


$dbh->disconnect();



1;




