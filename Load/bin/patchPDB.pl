#!/usr/bin/perl
 
use strict;
use DBI;
use GUS::Supported::GusConfig;

# workflow step replace all J/O with X in PDB file incorrectly. this script is to find
# such issue, and update database with correct PDB description/ids.
# pdb_def_file is the definition line of latest PDB data

my $usage = "patchPDB.pl pdb_def_file\n";
my $config = GUS::Supported::GusConfig->new("$ENV{GUS_HOME}/config/gus.config");

my $sid  = $config->getDbiDsn();
my $user = $config->getDatabaseLogin();
my $pass = $config->getDatabasePassword();
my $file = shift or die $usage;
my %hash;

open F, $file;
open MM, ">mismatch.list";
open LOG, ">log";

while(<F>){
  chomp;
  s/^>//;
  s/mol:protein\s+//;
  s/length:\d+\s+//;
  my ($id, @a) = split /\s/, $_;
  $hash{uc($id)} = join(" ", @a);
}

my $dbh = DBI->connect($sid, $user, $pass,
                       {RaiseError => 1, AutoCommit => 1 })  
             || die "Database connection note mode: $DBI::errstr";

my $sql = <<EOSQL;
SELECT eas.source_id,eas.description
FROM dots.ExternalAaSequence eas, 
sres.ExternalDatabaseRelease edr, 
sres.ExternalDatabase ed
WHERE eas.external_database_release_id = edr.external_database_release_id 
AND edr.external_database_id = ed.external_database_id 
AND ed.name in ('PDBProteinSequences_RSRC','PDB protein sequences')
EOSQL

my $sth = $dbh->prepare($sql);
$sth->execute;

while (my $row = $sth->fetchrow_arrayref) {
  my ($source_id, $desc) = @$row;
  my $id = uc($source_id);
  
  if(exists $hash{$id}) {
    if($hash{$id} ne $desc) { 
      print MM "MM $source_id $hash{$id} | $desc\n";
      ## update description, modification date
      &update_desc($dbh, $id, $hash{$id});
    } 
  } else { # key does not exist

    # test if O|J exists
    if($id =~ /X/) { 
      (my $j_id = $id) =~ s/X/J/;
      (my $o_id = $id) =~ s/X/O/;

      if (exists $hash{$j_id} && exists $hash{$o_id}) {
        print MM "JO $id $j_id $hash{$j_id} $desc | $o_id $hash{$j_id} $desc\n"; # 
        # in eupath database, there is only unique id, such '1a8r_X', 
        # but PDB has both 1a8r_J and 1a8r_O
        # in such case, update to J id arbitrarily? or ignore it
        (my $new_id = $source_id) =~ s/X/J/;
        ## update id to J ID
        &update_id($dbh, $new_id, $id);
      } elsif (exists $hash{$j_id}) {
        print MM "J $id $j_id\n";
        (my $new_id = $source_id) =~ s/X/J/;
        &update_id($dbh, $new_id, $id);
        ## update id to J ID
      } elsif (exists $hash{$o_id}) {
        print MM "O $id $o_id\n";
        (my $new_id = $source_id) =~ s/X/O/;
        &update_id($dbh, $new_id, $id);
        ## update id to O ID
      }
    } else { # not X related issue 
      print MM "NO $source_id\n";
    }
  }
}
$sth->finish;
$dbh->commit;
$dbh->disconnect;

sub update_desc() {
  my ($dbh, $id, $desc) = @_;
  my $sql = <<EOSQL;
UPDATE dots.ExternalAaSequence 
SET description = ?, modification_date = SYSDATE
WHERE upper(source_id) = ?
EOSQL
  my $sth = $dbh->prepare($sql);
  $sth->bind_param(1, $desc);
  $sth->bind_param(2, $id);
  print LOG $sql. "DESC $desc | $id\n\n";
  $sth->execute();
  $sth->finish;
}

sub update_id() {
  my ($dbh, $new_id, $id) = @_;
  my $sql = <<EOSQL;
UPDATE dots.ExternalAaSequence 
SET source_id = ?, modification_date = SYSDATE
WHERE upper(source_id) = ?
EOSQL
  my $sth = $dbh->prepare($sql);
  $sth->bind_param(1, $new_id);
  $sth->bind_param(2, $id);
  print LOG $sql. "ID $new_id | $id\n\n";
  $sth->execute();
  $sth->finish;
}
