use strict;
use warnings;
package ApiCommonData::Load::OwlReader;
## TODO
## move to another package tree where it belongs (???)
use Digest::MD5;
use RDF::Trine;
use RDF::Query;
use File::Basename;
use Env qw/PROJECT_HOME SPARQLPATH/;
use Data::Dumper;


sub new {
  my ($class, $owlFile) = @_;
  my $self = bless {}, $class;
	$self->{config} = {
		file => $owlFile,
		dbfile => "$owlFile.sqlite",
		md5file => "$owlFile.md5"
	};
	$self->loadOwl();
	unless ($SPARQLPATH){
		$SPARQLPATH = "$PROJECT_HOME/ApiCommonData/Load/lib/SPARQL";
	}
	$self->loadQueries();
	return $self;
}

sub getQueries{
	return $_[0]->{config}->{queries};
}

sub loadQueries{
	my ($self) = @_;
	opendir(DH, $SPARQLPATH) or die "Cannot open directory $SPARQLPATH: $!\n";
	my @files = grep { /\.rq$/i } readdir(DH);
	my %queries;
	foreach my $file (@files){
		my $name = basename($file, '.rq');
		open(FH, "<$SPARQLPATH/$file") or die "Cannot read $file: $!\n";
		my @lines = <FH>;
		close(FH);
		my $sparql = join("", @lines);
		$queries{$name} = $sparql;
	}
	$self->{config}->{queries} = \%queries;
	# printf STDERR ("Queries available:\n\t%s\n", join("\n\t", keys %queries));
}

sub loadOwl {
	my($self) = @_;
	my $dbfile = $self->{config}->{dbfile};
	my $owlFile = $self->{config}->{file};
	my $exists = -e $dbfile;
	my $name = basename($owlFile);
	if($exists && ! $self->fileIsCurrent($owlFile)){
		$exists = 0;
		unlink($dbfile);
		$self->writeMD5($owlFile);
	}
	my $model = RDF::Trine::Model->new(
	    RDF::Trine::Store::DBI->new(
	        $name,
	        "dbi:SQLite:dbname=$dbfile",
	        '',  # no username
	        '',  # no password
	    ),
	);
	unless( $exists ) { ## assumes existing dbfile is loaded
		my $parser = RDF::Trine::Parser->new('rdfxml');
		$parser->parse_file_into_model(undef, $owlFile, $model);
	}
	$self->{config}->{model} = $model;
}
	


sub getLabelsAndParentsHashes {
  my ($self) = @_;

	my $it = $self->execute('get_entity_parent_column_label');
  my $propertyNames = {};
  my $propertySubclasses = {};
	my $propertyOrder = {};
	my $otherAttrs = {};
	while (my $row = $it->next) {
		my $sourceid = $self->getSourceIdFromIRI($row->{entity}->as_hash()->{iri});
		my $parentid = $self->getSourceIdFromIRI($row->{parent}->as_hash()->{iri});
		$parentid =~ s/^.*#(.+)$/$1/; ## handle owl#Thing
		$propertySubclasses->{$parentid} ||= [];
		push(@{$propertySubclasses->{$parentid}}, $sourceid);
		my $col = $row->{column} ? $row->{column}->as_hash()->{literal} : "";
		my $label = $row->{label} ? $row->{label}->as_hash()->{literal} : "";
		my $order = $row->{order} ? $row->{order}->as_hash()->{literal} : 99;
		my $repeated = $row->{repeated} ? $row->{repeated}->as_hash()->{literal} : "";
    if($repeated){ $repeated =~ s/^"|"$//g }
		$propertyOrder->{$sourceid} = $order;
		$propertyNames->{$sourceid} ||= $label; ## do not overwrite first label, use label that appears first in the OWL
    $otherAttrs->{$sourceid}->{repeated} = $repeated;
	}
	foreach my $parentid (keys %$propertySubclasses){
		$propertyOrder->{$parentid} ||= 99;
	}
  return($propertyNames, $propertySubclasses, $propertyOrder, $otherAttrs);
}

sub execute {
	my ($self, $queryname, $bind) = @_;
	die("$queryname missing, query file was not loaded: $SPARQLPATH/$queryname.rq\n") unless(defined($self->{config}->{queries}->{$queryname}));
	my $sparql = $self->{config}->{queries}->{$queryname};
	if($bind && ref($bind) eq 'HASH'){
		while(my ($key, $val) = each %$bind){
			$sparql =~ s/\{$key\}/$val/g;
		}
	}
	my $query;
	eval{ $query = RDF::Query->new($sparql); };
	unless($query){
		print STDERR "Cannot create query from $queryname:\n$sparql\nCheck query syntax\n";
		exit;
	}
		
		
	return $query->execute( $self->{config}->{model} );
}

sub getTerms {
	my ($self) = @_;
	my %seen = (
		'Thing' => {
				sid => 'Thing',
				name => 'Thing',
			 	uri => 'http://www.w3.org/2002/07/owl#Thing',
				obs => 'false',
		}
	);
 	my $it = $self->execute('get_terms');
		while (my $row = $it->next) {
		my $uri = $row->{entity}->as_hash()->{iri}|| $row->{entity}->as_hash()->{URI};
	  next unless $uri;
		my $sid = $self->getSourceIdFromIRI($uri);
		die "Cannot get source id from $uri" unless $sid;
		my $name = $row->{label} ? $row->{label}->as_hash()->{literal} : "";
		unless($name){if($uri =~ /#(.+)$/){ $name = $1; }} # use "Thing" for name
		my $def = $row->{def} ? $row->{def}->as_hash()->{literal} : "";
		$def =~ s/[\n\t]+/ /g;
		my $obs = $row->{obs} ? $row->{obs}->as_hash()->{literal} : "false";
	# printf("$sid\t$def\n");next;
		if(defined($seen{$sid})){
	 		unshift(@{$seen{$sid}->{def}}, $def);
		}
		else{
			$seen{$sid} = {
				sid => $sid,
				name => $name,
			 	uri => $uri,
				def => [$def],
				obs => $obs
			};
		}
	}
	my @terms = sort { $a->{sid} cmp $b->{sid} } values %seen;
	return \@terms;
}

sub getRelationships {
	my ($self) = @_;
	my @seen;
 	my $it = $self->execute('get_isa_relations');
	while (my $row = $it->next) {
		my $uri = $row->{entity}->as_hash()->{iri}|| $row->{entity}->as_hash()->{URI};
	  next unless($uri);
		my $sid = $self->getSourceIdFromIRI($uri);
		die "Cannot get source id from $uri" unless $sid;
		my $pid;
		if($row->{parent}){
			$uri = $row->{parent}->as_hash()->{iri}|| $row->{parent}->as_hash()->{URI};
			next unless($uri);
			$pid = $self->getSourceIdFromIRI($uri);
		}
		else{
			$pid = "";
		}
		push(@seen, {
			subject => $sid,
			type => "subClassOf",
			object => $pid
		});
	}
	return \@seen;
}

sub getMultifilters {
	my ($self) = @_;
	my @seen;
	
 	my $it = $self->execute('get_termtypes');
	while (my $row = $it->next) {
		my $uri = $row->{entity}->as_hash()->{iri}|| $row->{entity}->as_hash()->{URI};
	  next unless($uri);
		my $sid = $self->getSourceIdFromIRI($uri);
		die "Cannot get source id from $uri" unless $sid;
		push(@seen, {
			subject => $sid,
			type => "EUPATH_0000271",
			object => "EUPATH_0001005"
		});
	}
	return \@seen;
}

sub getDisplayOrder {
	my ($self) = @_;
	my %seen;
 	my $it = $self->execute('get_display_order');
	while (my $row = $it->next) {
		my $uri = $row->{entity}->as_hash()->{iri}|| $row->{entity}->as_hash()->{URI};
	  next unless($uri);
		my $sid = $self->getSourceIdFromIRI($uri);
		die "Cannot get source id from $uri" unless $sid;
		$seen{$sid} = $row->{display_order}->as_hash()->{literal};
	}
	return \%seen;
}

sub getVariable {
	my ($self) = @_;
	my %seen;
 	my $it = $self->execute('get_variable');
	while (my $row = $it->next) {
		my $uri = $row->{entity}->as_hash()->{iri}|| $row->{entity}->as_hash()->{URI};
	  next unless($uri);
		my $sid = $self->getSourceIdFromIRI($uri);
		die "Cannot get source id from $uri" unless $sid;
    $seen{$sid} ||= [];
		push(@{$seen{$sid}}, $row->{variable}->as_hash()->{literal});
	}
  while(my($sid,$vars) = each %seen){
    $seen{$sid} = join(",", sort @$vars);
  }
	return \%seen;
}

sub getSourceIdFromIRI {
	my($self,$iri) = @_;
	if($iri =~ /#(.+)$/){ return $1; } # http://domain/owl#Thing => Thing
	if($iri =~ /^.*:\/\//){ $iri =~ s/^.*:\/\///; } # cut protocol://
	my @addr = split(/\//, $iri);
	if(2 > @addr){ return $iri; } # nothing to split
	elsif(3 > @addr) { return pop(@addr); } # pattern is protocol://domain/id
	else{ 
		## http://domain-name/sub/PREFIX_0000 or
		## http://domain-name/sub/PREFIX/0000
		my ($domain, $sd, @id) = @addr;
		return join("_", @id);
	}
}

sub writeMD5 {
	my ($self, $file) = @_;
	my $md5file = $self->{config}->{md5file};
	my $ctx = Digest::MD5->new;
	open(my $fh, $file);
	$ctx->addfile($fh);
	my $md5 = $ctx->hexdigest();
	close($fh);
	open(FH, ">$md5file") or die "Cannot write $md5file:$!\n";
	print FH "$md5\n";
	close(FH);
}

sub fileIsCurrent {
	my ($self, $file) = @_;
	my $md5file = $self->{config}->{md5file};
	unless (-e $md5file){
		return 0;
	}
	open(FH, "<$md5file") or die "Cannot read $md5file:$!\n";
	my $oldmd5 = <FH>; 
	chomp $oldmd5;
	my $ctx = Digest::MD5->new;
	open(my $fh, $file);
	$ctx->addfile($fh);
	my $md5 = $ctx->hexdigest();
	close($fh);
	if($md5 ne $oldmd5){
		return 0;
	}
	return 1;
}

1;
