package ApiCommonData::Load::GeoLookup;

#
# TO DO: implement the VEuGEO lookup from GADM ID to ontology term name
#

use strict;
use warnings;
use Moose;

# use Geo::ShapeFile;
use Encode qw/decode/;
use Encode::Detect::Detector qw/detect/;


#
# Usage:
#
# my $geolookup = ApiCommonData::Load::GeoLookup->new({ shapefiles_directory => '/path/...' });
# my ($gadm_names, $gadm_ids, $veugeo_names) = $geolookup->lookup($lat, $long);
# # returns in this order: country, admin1, admin2
# # e.g.
# ( [ 'United States', 'Illinois', 'Cook' ],
#   [ 'USA', 'USA.14_1', 'USA.14.16_1' ],
#   [ 'United States', 'Illinois', 'Cook (Illinois)' ]  )
#
# If 'dbh' and 'VEuGEO_extDbRlsId' are not given, the disambiguated veugeo_names
# array (third arrayref of result) will be empty
#
#
# Required constructor args:
#
# shapefiles_directory => 'PATH_TO_SHAPEFILES',
#
# # where the shapefiles are located at <shapefiles_directory>/<shapefile_prefix><LEVEL>.*
# # where LEVEL is 0, 1 or 2
#
# Optional constructor args (defaults shown):
#
# shapefile_prefix => 'gadm36_',
# num_levels => 3,
# max_radius_degress => 0.025
# radius_steps => 10,
#
# Optional, no defaults, but disambiguated name lookup won't work without them
# dbh => GUS_database_handle,
# VEuGEO_extDbRlsId => external database release ID for VEuGEO (TBC if ontologyterm or ontologytermrelationship table)
#

has 'shapefiles_directory' => (
  is => 'ro',
  required => 1,
);

has 'shapefile_prefix' => (
  is => 'ro',
  default => 'gadm36_',
);

has 'num_levels' => (
  is => 'ro',
  default => 3,
);

has 'max_radius_degrees' => (
  is => 'ro',
  default => 0.025,
);

has 'dbh' => (
  is => 'ro',
);

has 'VEuGEO_extDbRlsId' => (
  is => 'ro',
);



# private lazy attribute
# cannot be provided to constructor
has '_shapefiles' => (
  is => 'ro',
  lazy => 1,
  builder => '_load_shapefiles',
  init_arg => undef,
);

sub _load_shapefiles {
  my $self = shift;
  my $_shapefiles = [];
  for (my $level = 0; $level < $self->num_levels; $level++) {
    my $shapefile_stem = join '', $self->shapefiles_directory, '/', $self->shapefile_prefix, $level;
    # $_shapefiles->[$level] = Geo::ShapeFile->new($shapefile_stem);
  }
  return $_shapefiles;
}


sub lookup {
  my ($self, $lat, $long, $max_level) = @_;

  $max_level = 2 unless (defined $max_level && $max_level =~ /^[012]$/);

  # some default parameters that we may choose to add as command-line options later
  my $max_radius_degrees = 0.025; # max distance in degrees to search around points that don't geocode (around 2.5 km)
  my $radius_steps = 10; # how many steps to take expanding the search around the center point

  my $result_names = [];
  my $result_ids = [];
  my $result_veugeo_names = [];
  my $pi = 3.14159265358979;
 RADIUS:
  for (my $radius=0; $radius<$self->max_radius_degrees; $radius += $self->max_radius_degrees/$self->radius_steps) {
    for (my $angle = 0; $radius==0 ? $angle<=0 : $angle<2*$pi; $angle += 2*$pi/8) { # try N, NE, E, SE, S etc
      # do the geocoding lookup
      my $query_point = Geo::ShapeFile::Point->new(X => $long + cos($angle)*$radius,
						   Y => $lat + sin($angle)*$radius);
      my $parent_id; # the ID, e.g. AFG of the higher level term that was geocoded

      foreach my $level (0 .. $max_level) {
	last if ($level > 0 && !defined $parent_id);
	# print "Scanning level $level\n" if $verbose;
	my $shapefile = $self->_shapefiles->[$level];
	my $num_shapes = $shapefile->shapes;
	my @found_indices;
	foreach my $index (1 .. $num_shapes) {
	  if ($level == 0 || is_child_of_previous($index, $shapefile, $parent_id, $level-1)) {
	    my $shape = $shapefile->get_shp_record($index);
	    if ($shape->contains_point($query_point)) {
	      push @found_indices, $index;
	    }
	  }
	}
	if (@found_indices == 1) {
	  my $index = shift @found_indices;
	  my $dbf = $shapefile->get_dbf_record($index);
	  my $gadm_id = $dbf->{"GID_$level"};
	  push @{$result_ids}, $gadm_id;
	  push @{$result_names}, cleanup($dbf->{"NAME_$level"});
	  if ($self->dbh && $self->VEuGEO_extDbRlsId) {
	    my $veugeo_name = $self->getVEuGEOname($gadm_id);
	    push @{$result_veugeo_names}, $veugeo_name;
	  }
	  $parent_id = $gadm_id;

	} elsif (@found_indices > 0) {
	  warn "Warning: multiple polygons matched for ($lat, $long) at level $level\n";
	}
      }
      last RADIUS if (@{$result_ids} > 0);
    }
  }
  return ($result_names, $result_ids, $result_veugeo_names);
}

sub getVEuGEOname {
  my ($self, $gadm_id) = @_;

  #
  # TO DO: lookup sres.ontology tables with GADM ID and return the ontologyterm.name
  #

  return "Nice disambiguated name";
}


no Moose;
__PACKAGE__->meta->make_immutable;

# regular functions follow

sub is_child_of_previous {
  my ($index, $shapefile, $parent_id, $level) = @_;
  my $dbf = $shapefile->get_dbf_record($index);
  return $dbf->{"GID_$level"} eq $parent_id;
}


# fix some issues with encodings and whitespace in place names
sub cleanup {
  my $string = shift;
  my $charset = detect($string);
  if ($charset) {
    # if anything non-standard, use UTF-8
    $string = decode("UTF-8", $string);
  }
  # remove leading and trailing whitespace
  $string =~ s/^\s+//;
  $string =~ s/\s+$//;
  # fix any newlines or tabs with this
  $string =~ s/\s+/ /g;
  return $string;
}
