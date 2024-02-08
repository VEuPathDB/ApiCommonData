package ApiCommonData::Load::SequenceOntologyLookup;

use strict;

use DBI;
use DBD::Pg;

use Data::Dumper;

use GUS::Supported::GusConfig;

sub getSequenceOntologyTermsHash {$_[0]->{_sequence_ontology_terms_hash}}
sub setSequenceOntologyTermsHash {
    my ($self, $extDbName, $dbh) = @_;

    my $ar = $extDbName;
    if(ref($extDbName) eq 'SCALAR') {
        $ar = [ $extDbName ];
    }

    my $dbNames = join(",", map { "'$_'" } @$ar);

    my $sql = "select t.name, t.source_id
from sres.ontologyterm t,
 sres.externaldatabase d,
 sres.externaldatabaserelease r
where d.name in ($dbNames)
 and d.external_database_id = r.external_database_id
and r.external_database_release_id = t.external_database_release_id
UNION
select t.name, t.source_id
from sres.ontologyterm t,
  sres.ontologyrelationship rel,
 sres.externaldatabase d,
 sres.externaldatabaserelease r
where d.name in ($dbNames)
 and d.external_database_id = r.external_database_id
and r.external_database_release_id = rel.external_database_release_id
and rel.subject_term_id = t.ontology_term_id
";

    my $sh = $dbh->prepare($sql);
    $sh->execute();

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

  $self->setSequenceOntologyTermsHash($extDbName, $dbh);
  $dbh->disconnect();
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
