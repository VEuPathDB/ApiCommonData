

package ApiCommonData::Load::WGCNAME;
use base qw(CBIL::TranscriptExpression::DataMunger::Loadable);

use strict;
use CBIL::TranscriptExpression::Error;
use Data::Dumper;
use Exporter;
use File::Basename;

my $PROTOCOL_NAME = 'WGCNAME';

 sub getSamples                 { $_[0]->{modules} }
 sub setSamples                 { $_[0]->{modules} = $_[1] }


sub new {
    my ($class, $args) = @_;
    my $self = $class->SUPER::new($args);
    return $self;
}

sub munge {
    my ($self) = @_;
    
    my @names;
    my @fileNames;
    
    my $samplesHash = $self->groupListHashRef($self->getSamples());
    
    #print Dumper $samplesHash;

    foreach my $key (keys %{ $samplesHash }) {
	my $file =  @{$samplesHash->{$key}}[0];
	#print $file . "\n";

	push(@names, $key);
	push(@fileNames, $file);
    }


  $self->setInputProtocolAppNodesHash();
  $self->setNames(\@names);                                                                                                  
  $self->setFileNames(\@fileNames);
  $self->setProtocolName($PROTOCOL_NAME);
  $self->setSourceIdType("module");

  #$self->{doNotLoad} = 0;
  
  $self->createConfigFile();


}
