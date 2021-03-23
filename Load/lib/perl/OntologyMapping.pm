package ApiCommonData::Load::OntologyMapping;

use strict;
use warnings;

use ApiCommonData::Load::OwlReader;
use File::Basename qw/basename dirname/;
use Env qw/PROJECT_HOME/;
use XML::Simple;
use Data::Dumper;

sub getOntologyMapping { return $_[0]->{_ontology_mapping} }

sub new {
  my ($class,$owlFile,$functionsFile) = @_;
  my $self = {};
  bless ($self, $class);
  $self->setOntologyMapping($owlFile,$functionsFile);
  return $self;
}

sub setOntologyMapping{
  my ($self,$owlFile,$functionsFile,$sortByIRI) = @_;
  unless( -f $owlFile ){
    my $owlDir = "$PROJECT_HOME/ApiCommonData/Load/ontology/release/production";
  	my $tmp = "$owlDir/$owlFile.owl";
  	if(-f $tmp){
  		$owlFile = $tmp;
  	}
  	else{
  		opendir(DH, dirname($owlDir));
  		my @owls = grep { /\.owl$/i } readdir(DH);
  		close(DH);
  		print STDERR "Error: $owlFile does not exist\n";
  		printf STDERR ("Error: %s does not exist\nAvailable owl files in %s:\n%s\n",
  			$owlFile, dirname($tmp), join("\n", @owls));
  		exit;
  	}
  }
  my $funcToAdd = {};
  if($functionsFile && -e $functionsFile){
    $funcToAdd = $self->readFunctionsFile($functionsFile);
  }
  my $owl = $self->getOwl($owlFile);
  my $vars = $self->getTermsFromOwl($owl, $funcToAdd);
  my $materials = $self->getMaterialTypesFromOwl($owl);
  my $protocols = $self->getProtocols();
  my @terms;
  push(@terms, $_) for @$materials;
  push(@terms, $_) for @$protocols;
  push(@terms, $_) for @$vars;
  my $data = {
    ontologymappings => [
      {
        ontologyTerm => \@terms
      }
    ]
  };
  $self->{_ontology_mapping} = $data;
  return $data;
}

sub getOntologyXml {
  my ($self) = @_;
  my $data = $self->getOntologyMapping();
  return XMLout($data, KeepRoot => 1, AttrIndent => 0);
}

sub printXml {
  my ($self,$outFile) = @_;
  my $xml = $self->getOntologyXml();
  if(defined($outFile)){
    open(FH, ">$outFile") or die "Cannot write $outFile:$!";
    print FH $xml;
    close(FH);
  }
  else { print $xml }
}
  
sub getOwl {
  return ApiCommonData::Load::OwlReader->new($_[1]);
}

sub getTermsFromOwl{
  my ($self,$owl,$funcToAdd,$sortByIRI) = @_;
  my $it = $owl->execute('get_column_sourceID');
  my %terms;
  while (my $row = $it->next) {
  	my $iri = $row->{entity}->as_hash()->{iri}|| $row->{entity}->as_hash()->{URI};
  	my $names = $row->{vars}->as_hash()->{literal};
  	#my $name = "";
  	if(ref($names) eq 'ARRAY'){
  		#$name = lc($names->[0]);
  	}
  	else {
  		my $name = lc($names);
  		if($name =~ /,/){
  			my @splitnames = split(/\s*,\s*/, $name);
  			$names = \@splitnames;
  		}
  		else {
  			$names = [ $name ];
  		}
  	}
  	my %allnames;
  	foreach my $n (@$names){
     #if( $n =~ /::/ ) {
     #  my ($mdfile,$colName) = split(/::/, $n);
     #  print STDERR ("$colName\t$mdfile\n");
     #  delete $allnames{$n};
     #  $n = $colName;
     #}
  		$allnames{$n} = 1;
  	}
  	my $sid = $owl->getSourceIdFromIRI($iri); 	
  	if(defined($terms{$sid})){
  		foreach my $n (@{ $terms{$sid}->{name} } ){ # all rows for this $sid previously read
  			$allnames{$n} = 1;
  		}
  	}
  	@$names = sort keys %allnames;
    my @funcs;
  	my $rank = 1;
    $funcToAdd //= {};
    if(0 < keys %$funcToAdd){
  	  my %funcHash;
  	  foreach my $id (map { lc } ($sid, @$names)){
        if($funcToAdd->{$id}){
  	  		foreach my $func ( keys %{$funcToAdd->{$id}} ){
  	  			$funcHash{$func} = $funcToAdd->{$id}->{$func};
  	  		}
        }
  	  }
  	  @funcs = sort { $funcHash{$a} <=> $funcHash{$b} } keys %funcHash;
    }
    $terms{$sid} = { 'source_id' => $sid, 'name' =>  $names, 'type' => 'characteristicQualifier', 'parent'=> 'ENTITY', 'function' => \@funcs };
  }
  my @sorted;
  if($sortByIRI){
    @sorted = sort { $a->{source_id} cmp $b->{source_id} } values %terms;
  }
  else {
    @sorted = sort { $a->{name}->[0] cmp $b->{name}->[0] } values %terms;
  }
  return \@sorted;
}

sub getMaterialTypesFromOwl {
  my ($self,$owl) = @_;
  my $it = $owl->execute('top_level_entities');
  my %materialTypes;
  while (my $row = $it->next) {
  	my $iri = $row->{entity}->as_hash()->{iri};
  	my $sid = basename($iri); 	
  	my $name = $row->{label} ? $row->{label}->as_hash()->{literal} : "";
    $materialTypes{$name} = $sid;
  }
  my @sorted = ( { source_id => 'INTERNAL_X', type => 'materialType', name => [ 'INTERNAL' ] } ); 
  foreach my $type ( sort keys %materialTypes){
    push(@sorted, { source_id => $materialTypes{$type }, type => 'materialType', name => [ $type ] }); 
  }
  return \@sorted;
}

sub getProtocols {
  my %protocols = (
    communityObservation => 'EUPATH_0035127', # community-community observation
    communityHousehold => 'OBI_0600004', # community-household
    hhobservationprotocol => 'EUPATH_0015467', # household-household observation
    entomology => 'EUPATH_0000055', # household-entomology
    enrollment => 'OBI_0600004', # household-participant edge
    observationprotocol => 'BFO_0000015', # participant-observation edge
    'specimen collection' => 'OBI_0000659', # observation-sample edge
  );
  my @sorted;
  foreach my $prot ( sort keys %protocols ){
    push(@sorted, { source_id => $protocols{$prot}, type => 'protocol', name => [ $prot ] }); 
  }
  return \@sorted;
}

sub readFunctionsFile {
  my ($self, $functionsFile) = @_;
  my %funcToAdd;
	open(FH, "<$functionsFile") or die "Cannot read $functionsFile:$!\n";
	my $rank = 1;
	while(my $line = <FH>){
	  chomp $line;
	  my($sid, @funcs) = split(/\t/, $line);
	  $sid = lc $sid; # source ID or variable name
	  if(0 < @funcs){
			$funcToAdd{$sid} ||= {};
			foreach my $func (@funcs){
				$funcToAdd{$sid}->{$func} = $rank;
				$rank += 1;
			}
		}
	}
	close(FH);
  return \%funcToAdd;
}
1;

