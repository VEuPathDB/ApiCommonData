package ApiCommonData::Load::Biom::Lineages;
# parses ; separated string, trying to understand a few common cases
# originally developed for SILVA
# then extended for whatever might be popular 

use strict;
use warnings;
use List::Util qw/all/;
use List::MoreUtils qw/zip/;

sub new {
  my ($class, $unassignedLevelString, $levelNames, $maxStringLengthLevel) = @_;
  return bless {
    unassigned_level => $unassignedLevelString,
    level_names => $levelNames,
    level_max_length => $maxStringLengthLevel,
  }, $class;
}

sub getTermsFromObject {
  my ($self, $id, $o) = @_;
  my $unassignedLevel = $self->{unassigned_level};
  my @levelNames =  @{$self->{level_names}};

# The terms might come to us defined - although unlikely
  my @levels = map {$o->{$_}} @levelNames;

# Kludge the superkingdoms in
  if(defined $o->{superkingdom}){
    $levels[0] ||= $o->{superkingdom};
  }

  return $self->lineageO(\@levelNames, \@levels)
    if (grep {$_} @levels) && (all {not ref $_ } @levels);

  my $lineageTerm = $o->{taxonomy} || $o->{Taxonomy} || $id;

  my $lineageString = unpackLineageTerm(\@levelNames, $lineageTerm);

  return $self->lineageO([$unassignedLevel], [$lineageString])
    unless ($lineageString =~ m{;} or $lineageString =~ m{(Bacteria|Archaea|Eukarya)$}i);

  my $lineage = $self->splitLineageString($lineageString);
 
  return $self->lineageO(\@levelNames, $lineage)
   if @$lineage;

  return $self->lineageO([$unassignedLevel], [$id])
}

sub lineageO {
  my ($self, $levelNames, $levels) = @_;
  
  my $indexOfLastDefinedLevel;
  for my $i (0..$#$levels){
    $indexOfLastDefinedLevel = $i if defined $levels->[$i];
  }
  
  my @ks = @{$levelNames};
  my @vs =@{$levels};
  splice @ks, $indexOfLastDefinedLevel+1;
  splice @vs, $indexOfLastDefinedLevel+1;

  @vs = map {substr($_,0,$self->{level_max_length})} @vs;

  my %result = zip @ks, @vs;
  $result{lineage} = join(";",@vs);
  return \%result;
}

sub unpackLineageTerm {
  my ($levelNames, $lineageTerm) = @_;
  my @levelNames = @{$levelNames};

  if(ref $lineageTerm eq 'ARRAY'){
    return join (";", @{$lineageTerm});
  } elsif (ref $lineageTerm eq 'HASH'){
    my %h = %{$lineageTerm};
    # Arrange terms in order of level names we know, and add everything else at the end
    my %levelNames = {$_=>1} for @levelNames;

    if($h{superkingdom}){
      $h{$levelNames[0]} ||= $h{superkingdom};
      delete $h{superkingdom};
    }
    return join(" ",
      join(";", map {$h{$_}} @levelNames),
      map {$h{$_}} sort grep {not $levelNames{$_}} keys %h
    );
  } else {
    return $lineageTerm;
  }
}

sub splitLineageString {
  my ($self, $lineageString) = @_;
  my $numMaxTerms = scalar @{$self->{level_names}};
  my @lineage = split ";", $lineageString;
  s/^\s+// for @lineage;
  s/\s+$// for @lineage;

# Understand and ignore superkingdoms
# EBI metagenomics and doubtlessly elsewhere
  if ($lineage[0] =~ /^sk__/ && (! $lineage[1] || $lineage[1] eq "k__")){
    @lineage = grep {$_ ne "k__"} @lineage;
    $lineage[0] =~ s/^sk__/k__/;
  }

# Remove taxon level markers
  for (@lineage){
    s/^[kpcofgs]__//;
    s/^sk__//;
    s/D_[0-6]__//;
    s/^uncultured( bacterium)?$//;
  }
  
# Remove blank terms
# Not sure if this is desired for empty terms from the middle
  @lineage = grep {$_} @lineage;

# Remove NCBI root node
  if(@lineage && $lineage[0] eq 'cellular organisms'){
     shift @lineage;
  }

# Remove from the end terms that are just whitespace or underscores
  @lineage = reverse @lineage;
  while(@lineage && $lineage[0] =~ /^[\s_]*$/){
    shift @lineage;
  }
  @lineage = reverse @lineage;

# Remove from the end terms that are just the word 'none'
  @lineage = reverse @lineage;
  while(@lineage && $lineage[0] =~ /^none$/i){
    shift @lineage;
  }
  @lineage = reverse @lineage;

# Remove from the end terms that are the phrase 'ambiguous taxa'
  @lineage = reverse @lineage;
  while(@lineage && $lineage[0] =~ /^ambiguous ?_?taxa$/i){
    shift @lineage;
  }
  @lineage = reverse @lineage;

# Make sure there are at most $numMaxTerms
  do {
    my ($lastTerm, @extraTerms) = reverse splice @lineage, ($numMaxTerms-1);
    if($lastTerm){
      # If exactly the right number of terms or the most specific term has all the information put it back into @lineage, ignoring the rest
      if (all {index($lastTerm, $_)>-1} @extraTerms){
        push @lineage, $lastTerm;
      } else {
      # Otherwise put everything else back into @lineage, but with a space instead of ";"
        push @lineage, join (" ", reverse (@extraTerms), $lastTerm);
      }
    }
  };
# Make sure the last term - assuming this is species, we have a leaky abstraction here - is in binomial
# Uses capital letters for predicting what is what
  do {
    my ($lastTerm, $penultimateTerm, @terms) = reverse @lineage;
    if ($lastTerm && $penultimateTerm && $lastTerm =~ /^[a-z]/ && $penultimateTerm =~ /^[A-Z]/ && index (lc $lastTerm , lc $penultimateTerm) == -1){
      @lineage = ((reverse @terms), $penultimateTerm, "$penultimateTerm $lastTerm");
    }
  };
  return \@lineage;
}
1;
