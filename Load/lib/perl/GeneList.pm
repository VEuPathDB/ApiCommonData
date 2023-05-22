package ApiCommonData::Load::GeneList;
use base qw(CBIL::StudyAssayResults::DataMunger::Loadable); 
sub new { 
    my ($class, $args) = @_;
    my $self = $class->SUPER::new($args);
    $self->setSourceIdType("gene");
    $self->setProtocolName("gene_list");
    $self->setNames([$self->{listName}]);
    $self->setFileNames([$self->getInputFile()]);
    return $self;
}
sub munge {
    my ($self) = @_;
    $self->createConfigFile();
}
1;
