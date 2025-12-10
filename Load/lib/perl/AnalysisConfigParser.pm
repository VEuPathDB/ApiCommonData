package ApiCommonData::Load::AnalysisConfigParser;

use strict;

use XML::Simple;

use Data::Dumper;

use JSON;

sub getXmlFile { $_[0]->{xml_file} }
sub setXmlFile { $_[0]->{xml_file} = $_[1] }

sub getGlobalDefaults { $_[0]->{_global_defaults} }
sub setGlobalDefaults { $_[0]->{_global_defaults} = $_[1] }

sub getGlobalReferencable { $_[0]->{_global_referencable} }
sub setGlobalReferencable { $_[0]->{_global_referencable} = $_[1] }

sub new {
  my ($class, $xmlFile) = @_;

  unless(-e $xmlFile) {
    die "XML File $xmlFile doesn't exist.";
  }

  my $self = bless {}, $class;
  $self->setXmlFile($xmlFile);

  return $self;
}

sub parse {
  my ($self) = @_;

  my $xmlFile = $self->getXmlFile();

  my $xml = XMLin($xmlFile,  'ForceArray' => 1);

  my $defaults = $self->getGlobalDefaults();
  unless($defaults) {
    $defaults = $xml->{globalDefaultArguments}->[0]->{property};
  }

  my $globalReferencable = $self->getGlobalReferencable();
  unless($globalReferencable) {
    $globalReferencable = $xml->{globalReferencable}->[0]->{property};
    foreach my $ref (keys %$globalReferencable) {
      my $value = $globalReferencable->{$ref}->{value};
      $globalReferencable->{$ref} = $value;
    }
  }

  my $all_steps = [];


  my $steps = $xml->{step};

  foreach my $step (@$steps) {
    my $args = {};

    foreach my $default (keys %$defaults) {
      my $defaultValue = $defaults->{$default}->{value};

      if(ref($defaultValue) eq 'ARRAY') {
        my @ar = @$defaultValue;
        $args->{$default} = \@ar;
      }
      else {
        $args->{$default} = $defaultValue;
      }
    }

    my $properties = $step->{property};

    foreach my $property (keys %$properties) {
      my $value = $properties->{$property}->{value};
      my $isReference = $properties->{$property}->{isReference};

      if(ref($value) eq 'ARRAY') {
        push(@{$args->{$property}}, @$value);
      }
      elsif($isReference) {
        eval "\$args->{$property} = $value;";

        if($@) {
          die "ERROR:  isReference specified but value could not be evaluated:  $@";
        }
      }
      else {
          $args->{$property} = $value;
      }
    }

    $step->{arguments} = $args;
  }

  push @$all_steps, @$steps;

  return $all_steps;
}

1;
