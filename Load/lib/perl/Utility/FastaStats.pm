# POD documentation - main docs before the code
# $Id: FastaStats.pm 12794 2006-08-04 03:02:25Z mheiges $

=head1 NAME

FastaStats - module to report statistics of FASTA format sequence data
             and to compare two FASTA file data sets.

=head1 SYNOPSIS

    use FastaStats;

    my $f1 = new FastaStats( { dataset=>'seq.fsa', fullstats=>1} );
    my $f2 = new FastaStats( { dataset=>'/dir/of/fastaseqs', 
                               fullstats=>1} );
    
    $f1->printStats();
    
    if ($f1->equals($f2)) {
        print "Data sets are equal\n";
    } else {
        print "Data sets differ\n";
    }


=head1 DESCRIPTION

Generate and print information about a sequence FASTA data set (a FASTA file or a directory of
FASTA files). Information includes the number of sequences, residue counts, number of 
duplicate header ids. Input files may be compressed with gzip or compress.

Two FastaStat objects can be compared for equality. Equality 
defined as having the same sequences, independent of order and header id.
Two FASTA objects may be 'diff'ed to highlight sequences in one file that do 
not have identical sequence matches in the other.

=head1 AUTHOR - Mark Heiges

Email mheiges@uga.edu

=head1 CONTRIBUTORS

=head1 APPENDIX

The rest of the documentation details each of the object methods.
Internal methods are preceded with a _

=cut

package ApiCommonData::Load::Utility::FastaStats;

use Digest::MD5 qw(md5_base64);
use strict;
use vars qw($VERSION);

$VERSION = '0.03';

=head2 new

 Usage   : my $f1 = new FastaStats( { dataset=>'seq.fsa', 
                                      fullstats=>1} );
 Function: Returns a FASTA statistics object.
 Returns : FastaStat object.
 Args    : Named parameters:

            dataset - one FASTA file of one or more sequences or
                            a directory of one or more FASTA files
            fullstats - report residue counts. off by default
            listduplicates - list duplicated sequences by ID. off by default
=cut
sub new {
    my ($class, $args) = @_;
    my $self = bless {
        dataset        => $args->{dataset},
        fullstats      => $args->{fullstats} || 0,
        listduplicates => $args->{listduplicates} || 0,
        fileCount      => 0,
        seqSums        => {},
        seqCount       => undef,
        resCount       => 0,
        duplicateIDs   => [],
        duplicateSeqs  => [],
        residueStats   => {},
    }, $class;
    $self->_getStats();
    return $self;
}  


=head2 equals

 Usage   : print 'ok' if $f1->equals($f2);
 Function: comparison of two sequence sets
 Returns : 1 if the sequences contained in $f1 are the same as 
           those contained in $f2. The comparison is performed 
           on the sequence strings only, is case-insensitive 
           and the order of sequences is not important.
           Otherwise, returns 0.
 Args    : two FastaStat objects

=cut
sub equals {
    my ($self, $other) = @_;
    
    return 0 unless ($other->isa(__PACKAGE__));
    return 1 if ($self == $other);
    
    my $selfSet = $self->{'seqSums'};
    my $otherSet = $other->{'seqSums'};

    return 0 unless keys %$selfSet == keys %$otherSet;
    
    for my $chksum (keys %$selfSet) {
        return 0 unless $otherSet->{$chksum};
    }
    return 1;    

}

=head2 diff

 Usage   : $f1->diff($f2);
 Function: comparison of two sequence sets
           Prints to STDOUT sequence def line of sequences in $f1 that 
           have no identical sequence in $f2, and vice versa. Although 
           it's the sequence def lines that are reported, it's the  
           associated sequence that is being compared. The FASTA def
           lines are not involved in the comparisons. The reported ids
           should give you hints which sequences to manually compare for 
           differences. This method does not report a sequence alignment
           to delineate residue-level differences. Wouldn't it cool if
           it did?
 Args    : two FastaStat objects

=cut
sub diff {
    my ($self, $other) = @_;
    
    print 'Error. Not a ' . __PACKAGE__ . " object.\n" unless ($other->isa(__PACKAGE__));
    print '' if ($self == $other);
    
    my $selfSet = $self->{'seqSums'};
    my $otherSet = $other->{'seqSums'};
    for my $chksum (sort { $selfSet->{$a}[0] cmp $selfSet->{$b}[0] } (keys %$selfSet)) {
        if (! $otherSet->{$chksum} ) {
            print "No match in @{[$other->{dataset}]} for @{$selfSet->{$chksum}}\n";
        } elsif (@{$selfSet->{$chksum}} != @{$otherSet->{$chksum}}) {
            printf (
"Mismatch in number of redundant sequences.
%s has %d:
>%s
%s has %d:
>%s",
$self->{dataset},
scalar @{$selfSet->{$chksum}},
join ("\n>", @{$selfSet->{$chksum}}),
$other->{dataset},
scalar @{$otherSet->{$chksum}},
join ("\n>", @{$otherSet->{$chksum}})
);
       }
    }
    
    print "------------\n";
    
    for my $chksum (sort { $otherSet->{$a}[0] cmp $otherSet->{$b}[0] } (keys %$otherSet)) {
       unless ($selfSet->{$chksum}) {
        print "No match in @{[$self->{dataset}]} for @{$otherSet->{$chksum}}\n";
       }
    }
    return 1;    

}

=head2 printStats

 Usage   : $f1->printStats();
 Function: Print to STDOUT information about the FASTA data set
 Returns : 
 Args    : 

=cut
sub printStats {
    print &getFormatedStats;
}

=head2 getFormatedStats

 Usage   : $f1->printStats();
 Function: formats information about the FASTA data set
 Returns : String. Formated information about the FASTA data set 
 Args    : 

=cut
sub getFormatedStats {
    my ($self) = @_;
    my $thisFile = $self->{'dataset'};
        
    my $seqCount = $self->{'seqCount'};
    my $dupIDRef = $self->{'duplicateIDs'};
    my $dupSeqRef = $self->{'duplicateSeqs'};
    my $residueRef = $self->{'residueStats'};
    
    my $stats;
    
    $stats .= "__________________________\n";
    $stats .= "Summary for " . $thisFile . "\n";
    
    
    $stats .= "  Number of files: " . $self->{'fileCount'};
    $stats .= "\n";
        
    $stats .= "  Number of sequences: ";
    $stats .= $seqCount . "\n";
        
    $stats .= "  Duplicate ids: ";
    if (scalar(@$dupIDRef) > 0) {
        $stats .= join("\n", @$dupIDRef);
        $stats .= "\n";
    } else {
        $stats .= "none\n";
    }

    # report if duplicate seqs
    $stats .= "  Duplicate sequences: ";
    if (scalar(@$dupSeqRef) > 0) {
        if ($self->{'listduplicates'}) {
            $stats .= "\n";
            for (@$dupSeqRef) {
                $stats .= '      ' . 
                          join (', ', @{ $self->{'seqSums'}->{$_} }) . 
                          "\n";
            }
        } else {
            $stats .= scalar @$dupSeqRef . " sets\n";
        }
    } else {
        $stats .= "none\n";
    }
    
    # report residue counts
    if ( $self->{'fullstats'} ) {
        $stats .= "  Residue counts:\n";
        foreach my $key (sort(keys %$residueRef)) {
            $stats .= "   " . $key . " : " . $residueRef->{$key} . "\n"; 
        }
    }
    $stats .= "  Total residues: " . $self->{'resCount'} . "\n";
    $stats .= "--------------------------\n";
    $stats .= "\n";

    return $stats;
} #sub printStats


#######################
# "private" subroutines
#######################

sub _getStats {
    my ($self) = @_;
    
    if ( -f $self->{'dataset'} ) {
        $self->_getStatsForFile($self->{'dataset'});
        $self->{'fileCount'}++;
    } elsif ( -d $self->{'dataset'} ) {
        opendir(DIR, $self->{'dataset'}) or die("Cannot open directory");
        while (my $theFile = readdir(DIR)) {
            
            next if ($theFile =~ /^\.\.?$/);
            
            $self->{'fileCount'}++;
            $self->_getStatsForFile( $self->{'dataset'} . "/" . $theFile );
        }
        closedir(DIR);    }
}

# given a file name, return the following stats:
# number of sequences, list of duplicate ids, hashed counts of residues
sub _getStatsForFile {
    my ($self, $theFile) = @_;
    
    my ($s, $id, @ids, $byte, %count);
    
    $theFile =~ s/(.*\.gz)\s*$/gzip -dc < $1|/;
    $theFile =~ s/(.*\.Z)\s*$/uncompress -c < $1|/;

    open(FILE1, $theFile ) or die "Can not open " . $theFile . " for reading\n";
    
    while (my $line = <FILE1>) {
        chomp $line;
        if ($line =~ m/^>(.+)/) {
            # process any previous seq and then record new id
            push(@{$self->{'seqSums'}->{md5_base64($s)}}, $id) if ($s ne '');
            undef $s;
            $id = $1; 
            # record sequence id
            &_trim(\$id);
            push(@ids, $id);
            
            
        } else {    
            $line =~ s/[^\w]+//g;
            $line = uc($line);
            
            if ($self->{'fullstats'}) {
                # count residues
                for my $char (unpack ('C*', $line)) {
                    $self->{'residueStats'}->{chr($char)}++;
                    $self->{'resCount'}++;
                }

            } else {
                $self->{'resCount'} += length($line);
            }
            $s .= $line;
        } #if/else
    } #while

    # md5sum the final combined seq lines
    push(@{$self->{'seqSums'}->{md5_base64($s)}}, $id) if ($s);

    $self->{'seqCount'} += scalar(@ids);
    
    # duplicate id counts
    push @{$self->{'duplicateIDs'}}, grep { ++$count{$_} > 1 } @ids;

    push @{$self->{'duplicateSeqs'}}, grep {  scalar @{$self->{'seqSums'}->{$_}} > 1 } (keys %{$self->{'seqSums'}});

}

sub _trim {
    my ($s) = @_;
    $$s =~ s/^\s+//;
    $$s =~ s/\s+$//;
}
1;

__END__


