package ApiCommonData::Load::AnalysisConfigRepeatFinder;
use strict;
use warnings;
use Exporter qw(import);
our @EXPORT_OK = qw(displayAndBaseName);

sub displayAndBaseName {
    my $AnalysisConfig = shift;
#    print "$AnalysisConfig\n\n\n";
    #my $file = $AnalysisConfig;
    #print "$file";
    open (F, '<', $AnalysisConfig) or die "cant open the AC file";
  
    my %acHash;
    my %repHash;
    while(<F>) {
#	print "hello";
	chomp;
	next if /^\s+$/;
	if(/<property name="samples">/i .. /<\/property>/i  ) {
	    next unless  /<value>/i;
	    $_ =~ /<value>(.*)<\/value>/ ;
	    my($sample_display_name, $sample_internal_name) = split /\|/, $1;
	    if (exists $acHash{$sample_display_name}) {
		push @{$acHash{$sample_display_name}} , $sample_internal_name;
	    }
	    else {
		push @{$acHash{$sample_display_name}} , $sample_internal_name;
	    }
	}
	
	foreach my $sample (keys %acHash) {
#	    print "$sample first hash ok";
	    my $repDisplayName = $sample;
	    my $repBaseName;
	    if ($#{$acHash{$sample}}>=1) {
		my $rep1 = $acHash{$sample}[0];
		my $rep2 = $acHash{$sample}[1];
		my @base1 = split "", $rep1;
		my @base2 = split"", $rep2;
		for (my $i=0; $i <= @base1; $i++) {
		    if ($base1[$i] eq $base2[$i]) {
			$repBaseName.= $base1[$i];
		    }
		    else {
			last;
		    }
		}
	    }
	    else {
		next;
	    }
	    $repHash{$repDisplayName} = $repBaseName;
	}
    }
    
    foreach my $keys (keys %repHash) {
#	print $keys."\t".$repHash{$keys}."\n";
    }
#    close ($IN);
#    my $hashRef = \%repHash;
    return %repHash;
}
