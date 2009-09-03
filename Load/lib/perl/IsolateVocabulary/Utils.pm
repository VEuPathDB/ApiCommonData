package ApiCommonData::Load::IsolateVocabulary::Utils;

use strict;

use DBI;
use DBD::Oracle;

sub createDbh {
  my ($gusConfigFile) = @_;

  my @properties = ();
  my $gusconfig = CBIL::Util::PropertySet->new($gusConfigFile, \@properties, 1);

  my $u = $gusconfig->{props}->{databaseLogin};
  my $pw = $gusconfig->{props}->{databasePassword};
  my $dsn = $gusconfig->{props}->{dbiDsn};

  return DBI->connect($dsn, $u, $pw) or die DBI::errstr;
}


sub isValidType {
  my ($type) = @_;

  my @allowed = ('geographic_location',
                 'specific_host',
                 'product',
                 'isolation_source'
                );

  foreach(@allowed) {
    if($type eq $_) {
      return 1;
    }
  }
  return 0;
}


sub getAllOntologies {
  my ($dbh)  = @_;

  my $sql = "select term, type, isolate_vocabulary_id from apidb.isolatevocabulary";
  my $sh = $dbh->prepare($sql);
  $sh->execute();

  my $res = {};
  while(my ($term, $type, $id) = $sh->fetchrow_array()) {
    $res->{$term}->{$type} = $id
  }
  $sh->finish();

  return $res;
}

sub isIncluded {
  my ($self, $a, $v) = @_;

  unless($a) {
    return 0;
  }

  foreach(@$a) {
    return 1 if $v eq $_;
  }
  return 0;
}

1;
