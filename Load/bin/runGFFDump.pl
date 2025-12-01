#!/usr/bin/perl

use strict;
use DBI;
use Getopt::Long;

my %sites = ( 
              AmoebaDB        => 'amoeba.b25',
              CryptoDB        => 'cryptodb.b25',
              PlasmoDB        => 'plasmo.b25',
              ToxoDB          => 'toxo.b25',
              TriTrypDB       => 'tritrypdb.b25',
              FungiDB         => 'fungidb.b25',
              PiroplasmaDB    => 'piro.b25',
              MicrosporidiaDB => 'micro.b25',
              GiardiaDB       => 'giardiadb.b25',
              TrichDB         => 'trichdb.b25',
              SchistoDB       => 'schisto.b25',
              HostDB          => 'hostdb.b25', 
            );


my ($user, $pass, $commit);

my $usage =<<EOL;
to test: runGFFDump.pl -u username -p password
to run:  runGFFDump.pl -u username -p password -commit 
EOL

&GetOptions( 'u=s'      => \$user,
             'p=s'      => \$pass,
             'commit!'  => \$commit
           );

die $usage unless $user && $pass;

my %dbs; 
my %workflowVersion;

# step 1: copy lastest configs from oak.pcbi.upenn.edu, e.g. /var/www/FungiDB/fungidb.b25/gus_home/config/FungiDB/

while(my ($db, $bld) = each %sites) {

  my $cmd = "scp oak.pcbi.upenn.edu:/var/www/$db/$bld/gus_home/config/$db/* $ENV{GUS_HOME}/config/$db";
  system($cmd) if $commit;
}

# step 2: update model-config.xml and model.prop

foreach my $db (keys %sites) {

  # model-config.xml
  my $f = "$ENV{GUS_HOME}/config/$db/model-config.xml";
  open (F, "+< $f");
  my $out = '';
  my $count = 0;

  while(<F>) {
    s/<appDb\s+login=".*"/<appDb login="$user"/ and $count=0;
    s/password=".*"/password="$pass"/ if $count == 1;

    my $dns = $1 if m/connectionUrl="jdbc:oracle:oci:@(.*)"/;
    $dbs{$db} = $dns if $dns and $dns !~ /apicomm/i;

    $out .= $_;
    $count++;
  }

  seek(F, 0, 0);
  print F $out ;
  truncate(F, tell(F));
  close F; 

  # model.prop
  $f = "$ENV{GUS_HOME}/config/$db/model.prop";
  open (F, "+< $f");
  my $out = '';

  while(<F>) {
    s/STEP_ANALYSIS_JOB_DIR=.*$/STEP_ANALYSIS_JOB_DIR=$ENV{HOME}\/wdkStepAnalysisJobs/;
    $out .= $_;
  }

  seek(F, 0, 0);
  print F $out ;
  truncate(F, tell(F));
  close F ; 
}

# step 3: get workflowVersion 
open F, "$ENV{PROJECT_HOME}/ApiCommonModel/Model/config/stagingDirPaths.tab";
while(<F>) {
  chomp;
  next if /^#/;
  next if /^\s*$/;
  my($site, $ver) = split /\t/, $_;
  $ver =~ s/\/eupath\/data\/apiSiteFilesStaging\///;
  $ver =~ s/\/real.*$//;
  $ver =~ s/$site\///;

  $workflowVersion{$site} = $ver;
}

# step 4: clean APIDB.genegff
# step 5: generate config file
# step 6: run gffDumpMgr
# step 7: qa - not implemented yet

while(my ($site, $db) = each %dbs) {
  my $dbh = DBI->connect("dbi:Oracle:$db", $user,$pass) or die DBI->errstr;
  $dbh->{RaiseError} = 1;
  $dbh->{AutoCommit} = 0;

  my $sql = "delete from APIDB.genegff";
  my $sth = $dbh->prepare($sql);
  $sth->execute if $commit;
  $sth->finish; 

  $sql = "select distinct '#org='||o.name_for_filenames||'|'||ga.organism from webready.GeneAttributes_p ga, APIDB.organism o where o.taxon_id = ga.taxon_id and o.is_annotated_genome=1 order by 1";
  $sth = $dbh->prepare($sql);
  $sth->execute;

  open S, ">$site.config";
  print S "#project=$site  workflowVersion=$workflowVersion{$site}\n";

  while(my $row = $sth->fetchrow_arrayref) {
    print S $row->[0]. "\n";
  }
  $sth->finish;

  print S "#//";
  close S;
  $dbh->disconnect;

  my $cmd = "gffDumpMgr --configFile $site.config >$site.out 2>$site.err";
  system($cmd) if $commit;
}
