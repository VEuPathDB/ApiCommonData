package ApiCommonData::Load::SequenceOntologyLookup;

use strict;

use DBI;
use DBD::Pg;

use GUS::Supported::GusConfig;

sub getSequenceOntologyTermsHash {$_[0]->{_sequence_ontology_terms_hash}}
sub setSequenceOntologyTermsHash {
    my ($self, $extDbName, $dbh) = @_;

    my $sql = "select t.name, t.source_id
from sres.ontologyterm t,
 sres.externaldatabase d,
 sres.externaldatabaserelease r
where d.name = ?
 and d.external_database_id = r.external_database_id
and r.external_database_release_id = t.external_database_release_id
";

    my $sh = $dbh->prepare($sql);
    $sh->execute($extDbName);

    my %hash;
    while(my ($name, $sourceId) = $sh->fetchrow_array()) {
        $hash{$name} = $sourceId;
    }
    $sh->finish();

    $self->{_sequence_ontology_terms_hash} = \%hash;
}

sub new {
  my ($class, $extDbName, $gusConfigFile) = @_;

  my $gusconfig = GUS::Supported::GusConfig->new($gusConfigFile);
  my $dsn = $gusconfig->getDbiDsn();
  my $login = $gusconfig->getDatabaseLogin();
  my $password = $gusconfig->getDatabasePassword();

  my $dbh = DBI->connect($dsn, $login, $password, {RaiseError => 1})
      or die "Can't connect to the Sequence Ontology database: $DBI::errstr\n";

  my $self = bless({}, $class);

  $dbh->disconnect();
  $self->setSequenceOntologyTermsHash($extDbName, $dbh);

  return $self;
}

sub getSourceIdFromName {
    my ($self, $name) = @_;

    my $hash = $self->getSequenceOntologyTermsHash();
    my $sourceId = $hash->{$name};

    if($sourceId) {
        return $sourceId;
    }

    die "Could not find a source Id for name: $name"
}


1;
