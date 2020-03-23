use strict;
use warnings;

use lib "/home/wbazant/perl5/lib/perl5"; #Wojtek has Bio::Community there
use lib "$ENV{GUS_HOME}/lib/perl";

use ApiCommonData::Load::Biom;
use Test::More;

# http://biom-format.org/documentation/format_versions/biom-1.0.html
my $in = <<EOF;
{
    "id":null,
    "format": "1.0.0",
    "format_url": "http://biom-format.org",
    "type": "OTU table",
    "generated_by": "QIIME revision 1.4.0-dev",
    "date": "2011-12-19T19:00:00",
    "rows":[
            {"id":"GG_OTU_1", "metadata":{"taxonomy":["k__Bacteria", "p__Proteobacteria", "c__Gammaproteobacteria", "o__Enterobacteriales", "f__Enterobacteriaceae", "g__Escherichia", "s__"]}},
            {"id":"GG_OTU_2", "metadata":{"taxonomy":["k__Bacteria", "p__Proteobacteria", "c__Gammaproteobacteria", "o__Enterobacteriales", "f__Enterobacteriaceae", "g__Escherichia", "s__coli"]}},
            {"id":"GG_OTU_3", "metadata":null},
            {"id":"GG_OTU_4", "metadata":null},
            {"id":"GG_OTU_5", "metadata":null}
        ],
    "columns": [
            {"id":"Sample1", "metadata":{"p" : 1}},
            {"id":"Sample2", "metadata":null},
            {"id":"Sample3", "metadata":null},
            {"id":"Sample4", "metadata":null},
            {"id":"Sample5", "metadata":null},
            {"id":"Sample6", "metadata":null}
        ],
    "matrix_type": "sparse",
    "matrix_element_type": "int",
    "shape": [5, 6],
    "data":[[0,2,1],
            [1,0,5],
            [1,1,1],
            [1,3,2],
            [1,4,3],
            [1,5,1],
            [2,2,1],
            [2,3,4],
            [2,4,2],
            [3,0,2],
            [3,1,1],
            [3,2,1],
            [3,5,1],
            [4,1,1],
            [4,2,1]
           ]
}
EOF
# Bio::Community::IO doesn't read from scalars :( 
use File::Temp qw/ tempfile/;
my ($fh, $filename) = tempfile();
print $fh $in;
close $fh;

my @out = ApiCommonData::Load::Biom::biomFileContents(sub {""}, $filename);
diag explain @out;
ok(\@out);

done_testing;
