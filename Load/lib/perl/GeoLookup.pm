package ApiCommonData::Load::GeoLookup;

#
# TODO: implement the VEuGEO lookup from GADM ID to ontology term name
#


use Data::Dumper;
use strict;
use warnings;
use Moose;

use Encode;

# use Geo::ShapeFile;

#
# Usage:
#
# my $geolookup = ApiCommonData::Load::GeoLookup->new({ gadmDsn => 'dbi:Pg:host=/path/to/socket;port=1234' });

# my ($gadm_names, $gadm_ids, $veugeo_names) = $geolookup->lookup($lat, $long);
# Required constructor args:
#
# gadmDsn => 'dbi:Pg:host=/path/to/socket;port=1234',
#
# Optional constructor args (defaults shown):
#
# maxLevel => 2,
# coordinateSystem => 4326,
#
# Optional, no defaults, but disambiguated name lookup won't work without them
# VEuGEO_extDbRlsId => external database release ID for VEuGEO (TBC if ontologyterm or ontologytermrelationship table)
#

has 'gadmDsn' => (
    is      => 'ro',
    isa     => 'Str',
    default => 'dbi:Pg:database=gadm;host=localhost',
);

has 'gadmTable' => (
    is      => 'ro',
    isa     => 'Str',
    default => 'gadm_410',
);

has 'dbiUser' => (
    is      => 'ro',
    isa     => 'Str',
    default => 'postgres',
);

has 'dbh' => (
    is      => 'ro',
    isa     => 'DBI::db',
    lazy    => 1,
    builder => '_build_dbh',
);

sub _build_dbh {
  my $self = shift;

  return DBI->connect($self->gadmDsn, $self->dbiUser) or die DBI->errstr;
}

sub disconnect {
    my $self = shift;
    $self->dbh()->disconnect();
}

has 'maxLevel' => (
  is => 'ro',
  default => 2,
);

has 'coordinateSystem' => (
  is => 'ro',
  default => 4326,
);

has 'VEuGEO_extDbRlsId' => (
  is => 'ro',
);

# "private" cache attribute, see https://metacpan.org/pod/Moose::Meta::Attribute::Native::Trait::Hash
has '_cache' => (
  is => 'ro', # don't worry the cache will still be rw
  isa => 'HashRef',
  default => sub { return {} },
  traits => [ 'Hash' ],
  handles   => {
    set_cache     => 'set', # set_cache is now a GeoLookup object method
    get_cache     => 'get', # ditto here
    check_cache => 'exists', # and here
  },
);


sub lookup {
  my ($self, $lat, $long, $max_level) = @_;

  $max_level = $self->maxLevel unless (defined $max_level && $max_level =~ /^[012]$/);

  my $cache_key = "$lat:$long:$max_level";
  if ($self->check_cache($cache_key)) {
    print STDERR "Found cache key $cache_key\n";
    return $self->get_cache($cache_key);
  }

  my $dbh = $self->dbh();

  my $coordinateSystem = $self->coordinateSystem();
  my $gadmTable = $self->gadmTable();

  my $sql = "select name_0 as admin0
                  , name_1 || ' (' || name_0 || ')' as admin1
                  , name_2 || ' (' ||name_1 || ' - ' ||name_0 || ')' as admin2
                  , continent
             FROM $gadmTable
             WHERE ST_Contains(geom, ST_SetSRID(ST_MakePoint($long, $lat), $coordinateSystem))";

  my $sh = $dbh->prepare($sql);
  $sh->execute();

  my $result_names = [];
  my $rows;
  while(my @ar = $sh->fetchrow_array()) {
    my @cleaned = map { cleanup($_)} @ar;

    my ($admin0, $admin1, $admin2, $continent) = @cleaned;

    if($max_level < 2) {
      $admin2 = undef;
      if($max_level < 1) {
        $admin1 = undef;
      }
    }

    @cleaned = ($admin0, $admin1, $admin2, $continent);
    
    $result_names = \@cleaned;
    $rows++;
  }

  my $result_veugeo_names = [];
  # returns the just-set value
  return $self->set_cache($cache_key => [ $result_names, $result_veugeo_names ]);
}

sub getVEuGEOname {
  my ($self, $gadm_id) = @_;

  #
  # TO DO: lookup sres.ontology tables with GADM ID and return the ontologyterm.name
  #

  return "Nice disambiguated name";
}



1;

no Moose;
__PACKAGE__->meta->make_immutable;

# fix some issues with encodings and whitespace in place names
sub cleanup {
  my $string = shift;
  $string = decode("UTF-8", $string);

  # remove leading and trailing whitespace
  $string =~ s/^\s+//;
  $string =~ s/\s+$//;
  # fix any newlines or tabs with this
  $string =~ s/\s+/ /g;
  return $string;
}

1;
