package ApiCommonData::Load::BioperlMapParser;

use strict 'vars'; # TODO-AJM: Why just 'vars'?? Do we have
                   # strict-breaking 'subs' or 'refs' somewhere?

######CPAN Perl Libraries
use XML::Simple;

#############################################################
# Main Routine
# read xml file of BioPerl object to GUS object mapping rule
# and create object for plugin(s) to use to make GUS objects
##############################################################
sub new {
  my $class = shift;
  $class = ref($class) || $class;

  my $self = {};
  bless($self, $class);

  return $self;
}

sub parseMap {
  my ($self, $mapXml) = @_;

  my $simple = XML::Simple->new();
  my $mapping = $simple->XMLin($mapXml, forcearray => 1);

  my $mapper = $mapping->{'feature'};
  return $mapper;
}

1;
