package ApiCommonData::Load::GeoLookup;

#
# TODO: implement the VEuGEO lookup from GADM ID to ontology term name
#


use Data::Dumper;
use strict;
use warnings;
use Carp;
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
# we will use the same cache for lookups in both directions
# "$lat:$long:$max_level" => admin level names
# "Placename" => lat/long
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
    my $self = shift;
    carp "GeoLookup method 'lookup' is deprecated; use 'lookup_from_coords' instead.";
    return $self->lookup_from_coords(@_);
}


#
# Returns an array reference of the following place names (some can be undefined if not found, or are
# above the $max_level requested)
#
# [ $country, $admin1, $admin2, $continent ]
#
sub lookup_from_coords {
  my ($self, $lat, $long, $max_level) = @_;

  $max_level = $self->maxLevel unless (defined $max_level && $max_level =~ /^[012]$/);

  my $cache_key = "$lat:$long:$max_level";
  if ($self->check_cache($cache_key)) {
    return $self->get_cache($cache_key);
  }

  my $dbh = $self->dbh();
  my $coordinateSystem = $self->coordinateSystem();
  my $gadmTable = $self->gadmTable();

  my $sql = <<"SQL";
    SELECT name_0 as admin0
         , name_1 || ' (' || name_0 || ')' as admin1
         , name_2 || ' (' || name_1 || ' - ' || name_0 || ')' as admin2
         , continent
    FROM $gadmTable
    WHERE ST_Contains(geom, ST_SetSRID(ST_MakePoint(?, ?), ?))
SQL

  my $sth = $dbh->prepare($sql);
  $sth->execute($long, $lat, $coordinateSystem);

  # Fetch only the first row. There is no need to loop through more than one.
  my $row = $sth->fetchrow_arrayref();

  my $result = [];
  if ($row) {
    my ($admin0, $admin1, $admin2, $continent) = map { cleanup($_) } @$row;

    if ($max_level < 2) {
      $admin2 = undef;
      if ($max_level < 1) {
        $admin1 = undef;
      }
    }

    $result = [$admin0, $admin1, $admin2, $continent];
  }

  # Cache the result whether it's empty or contains data
  return $self->set_cache($cache_key => $result);
}

=head1 NAME

lookup_from_placenames - Fetches the geographic centroid of the closest land polygon for specified administrative regions.

=head1 SYNOPSIS

  my ($latitude, $longitude) = @{$geo->lookup_from_placenames('United States')};
  my ($latitude, $longitude) = @{$geo->lookup_from_placenames('United States', 'Kentucky')};
  my ($latitude, $longitude) = @{$geo->lookup_from_placenames('United States', 'Florida', 'Jackson')};

=head1 DESCRIPTION

This function queries a geographic database to find the centroid of the closest land polygon based on one to three administrative regions specified. The function dynamically adjusts its query to accommodate varying numbers of provided region names, ensuring the result is meaningful geographically and represents a "land" area. Results are cached to enhance performance on subsequent queries.

=head1 PARAMETERS

=over 4

=item B<$self>

The object instance on which the method is invoked.

=item B<@names> (list of strings)

A list of up to three administrative region names for which the geographic centroid is to be determined. These must be in the order of country, state/province, and county (GADM levels 0, 1, and 2).

=back

=head1 RETURNS

An array reference containing the latitude and longitude of the centroid of the closest land polygon to the geometric median of all polygons for the specified regions. If no suitable location is found, an empty array reference is returned.

=head1 EXAMPLE

  my $geo_instance = GeoLookup->new();
  my $coords = $geo_instance->lookup_from_placenames('India', 'West Bengal', 'Kolkata');
  print "Coordinates: Latitude = $coords->[0], Longitude = $coords->[1]\n";

=cut

sub lookup_from_placenames {
  my ($self, @names) = @_;
  die "At least one placename must be provided" unless @names;

  my $cache_key = join(':', @names);
  if ($self->check_cache($cache_key)) {
    return $self->get_cache($cache_key);
  }

  my $dbh = $self->dbh();
  my $gadmTable = $self->gadmTable();

  # Construct WHERE clause dynamically based on input names
  my @where_clauses;
  push @where_clauses, "name_0 = ?" if $names[0];
  push @where_clauses, "name_1 = ?" if $names[1];
  push @where_clauses, "name_2 = ?" if $names[2];
  my $where_clause = join(' AND ', @where_clauses);

  my $sql = <<"SQL";
    WITH selected_areas AS (
        SELECT geom
        FROM $gadmTable
        WHERE $where_clause
    ), median_point AS (
        SELECT ST_GeometricMedian(ST_Collect(ST_Centroid(geom))) AS geo_median
        FROM selected_areas
    )

    SELECT ST_AsText(
            ST_Centroid(
                (SELECT (ST_Dump(geom)).geom
                 FROM selected_areas
                 ORDER BY ST_Distance(ST_Centroid((ST_Dump(geom)).geom), (SELECT geo_median FROM median_point))
                 LIMIT 1)
            )
        ) AS closest_centroid_to_median
SQL

  my $sth = $dbh->prepare($sql);
  $sth->execute(@names);

  my $row = $sth->fetchrow_arrayref();
  my $result = [];
  if ($row) {
    my ($point_string) = $row->[0];  # Extract the closest centroid to median
    my ($latitude, $longitude) = parse_point($point_string);
    $result = [ $latitude, $longitude ];
  }

  return $self->set_cache($cache_key => $result);
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

sub parse_point {
  my $point_text = shift;

  # Example input: 'POINT(160.20464996960433 -9.184020678019793)'
  if ($point_text =~ /POINT\(\s*(\S+)\s+(\S+)\s*\)/) {
    my $longitude = $1; # yes they come
    my $latitude = $2;  # in this order
    # Reduce precision to something sensible
    $longitude = sprintf("%.6f", $longitude);
    $latitude = sprintf("%.6f", $latitude);
    return ($latitude, $longitude);
  } else {
    die "Invalid POINT format: '$point_text'";
  }
}

1;
