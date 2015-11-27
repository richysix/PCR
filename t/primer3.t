#!/usr/bin/env perl
# primer.t
use warnings; use strict;

use Test::More;
use Test::Exception;
use Test::MockObject;

use File::Which;
use Data::Dumper;

use PCR::Primer3;

# create mock config hash
my @names = ( qw{ 1_PRIMER_MIN_SIZE 1_PRIMER_OPT_SIZE 1_PRIMER_MAX_SIZE
    1_PRIMER_MIN_TM 1_PRIMER_OPT_TM 1_PRIMER_MAX_TM 1_PRIMER_PAIR_MAX_DIFF_TM
    1_PRIMER_MIN_GC 1_PRIMER_OPT_GC_PERCENT 1_PRIMER_MAX_GC
    1_PRIMER_LIB_AMBIGUITY_CODES_CONSENSUS 1_PRIMER_EXPLAIN_FLAG
    1_PRIMER_MAX_POLY_X 1_PRIMER_LOWERCASE_MASKING 1_PRIMER_PICK_ANYWAY
    1_PRIMER_NUM_RETURN } );

my @values = ( qw { 18 23 27 53 58 65 10 20 50 80 0 1 4 1 1 1 } );

my $cfg_hash;
for my $i ( 0 .. scalar @names - 1 ){
    $cfg_hash->{ $names[$i] } = $values[$i];
}

bless $cfg_hash, 'Crispr::Config';

# check Primer3-Bin exists
my $skip;
my $primer3_path = which( 'primer3_core' );
if( !$primer3_path ){
    # try checking environment variables
    if( defined $ENV{PRIMER3_BIN} && -e $ENV{PRIMER3_BIN} ){
        $cfg_hash->{'Primer3-bin'} = $ENV{PRIMER3_BIN};
    }
    else{
        $skip = 1;
    }
    # check primer3 config exists
    if( defined $ENV{PRIMER3_CONFIG} && -e $ENV{PRIMER3_CONFIG} ){
            $cfg_hash->{'Primer3-config'} = $ENV{PRIMER3_CONFIG};
    }
    elsif( defined $ENV{PRIMER3_BIN}  && -e $ENV{PRIMER3_BIN} ){
        my $primer3_config = $ENV{PRIMER3_BIN};
        $primer3_config =~ s/primer3_core/primer3_config\//;
        if( -e $primer3_config ){
            $cfg_hash->{'Primer3-config'} = $primer3_config;
        }
        else{
            $skip = 1;
        }
    }
    else{
       $skip = 1;
    }
}
else{
    # check primer3 config exists as well
    my $primer3_config = $primer3_path;
    $primer3_config =~ s/primer3_core/primer3_config\//;
    if( !-e $primer3_config ){
        $skip = 1;
    }
}

my $warning = "WARNING: Could not detect Primer3. Skipping Primer3 tests!\n" .
    "If Primer3 is installed but not in the current path, " .
    "set environment variables PRIMER3_BIN and PRIMER3_CONFIG to run these tests!\n";

if( $skip ){
    plan skip_all => $warning;
}
else{
    plan tests => 1 + 3 + 1 + 4 + 12;
}

# make a new primer3 object
my $primer3_object = PCR::Primer3->new(
    cfg => $cfg_hash,
);

# 1 test
isa_ok( $primer3_object, 'PCR::Primer3');

# test methods - 3 tests
my @methods = qw( cfg setAmpInput primer3 );

foreach my $method ( @methods ) {
    can_ok( $primer3_object, $method );
}

# check type constraints - 1 tests
throws_ok { PCR::Primer3->new( cfg => 'config_file' ) }
    qr/Validation failed/ms, 'method new called with string not a Hashref';

## check method calls - 4 tests
my $sequence = 'GTAAGCCGCGGCGGTGTGTGTGTGTGTGTGTGTTCTCCGTCATCTGTGTTCTGCTGAATGATGAGGACAGACGTGTTTCTCCAGCGGAGGAAGCGTAGAGATGTTCTGCTCTCCATCATCGCTCTTCTTCTGCTCATCTTCGCCATCGTTCATCTCGTCTTCTGCGCTGGACTGAGTTTCCAGGGTTCGAGTTCTGCTCGCGTCCGCCGAGACCTCGAGAATGCGAGTGAGTGTGTGCAGCCACAGTCGTCTGAGTTTCCTGAAGGATTCTTCACGGTGCAGGAGAGGAAAGATGGAGGA';
my $seq2 = 'GTGTATGTAGCTGTACTGTGTTTCGATCTGAAGATCAGCGAGTACGTGATGCAGCGCTTCAGTCCATGCTGCTGGTGTCTGAAACCTCGCGATCGTGACTCAGGCGAGCAGCAGCCTCTAGTGGGCTGGAGTGACGACAGCAGCCTGCGGGTCCAGCGCCGTTCCAGAAATGACAGCGGAATATTCCAGGATGATTCTGGATATTCACATCTATCGCTCAGCCTGCACGGACTCAACGAAATCAGCGACGAGCACAAGAGTGTGTTCTCCATGCCGGATCACGATCTGAAGCGAATCCTG';

my $amp = [ ['test_amp1', $sequence, undef, undef, [ [150,1] ], [ [14,20] ], undef, undef ],
            ['test_amp2', $seq2, undef, undef, [ [150,1] ], [ ], undef, undef ], ];
my $file;
ok( $file = $primer3_object->setAmpInput( $amp, undef, undef, '50-300', 1, 1, '.' ), 'run set amp input' );
is( $file, './AmpForDesign_1_1.txt', 'check file name' );

my $results;
ok( $results = $primer3_object->primer3( $file, 'int_1_primer3.out' ), 'run primer3' );
isa_ok( $results, 'ARRAY', 'is results an ArrayRef' );

# test primer attributes - 12 tests
is( $results->[0]->amplicon_name, 'test_amp1', 'check amp name 1' );
is( $results->[0]->pair_penalty, '1.777278', 'check pair penalty 1' );
is( $results->[0]->explain, 'considered 1, ok 1', 'check explain 1' );
is( $results->[0]->product_size_range, '50-300', 'check product size range 1' );
is( $results->[0]->left_primer->sequence, 'CATCTGTGTTCTGCTGAATGATG', 'check left primer seq 1' );
is( $results->[0]->right_primer->sequence, 'CTTCAGGAAACTCAGACGACTG', 'check right primer seq 1' );

is( $results->[1]->amplicon_name, 'test_amp2', 'check amp name 2' );
is( $results->[1]->pair_penalty, '0.174062', 'check pair penalty 2' );
is( $results->[1]->explain, 'considered 2, ok 2', 'check explain 2' );
is( $results->[1]->product_size_range, '50-300', 'check product size range 2' );
is( $results->[1]->left_primer->sequence, 'ATGTAGCTGTACTGTGTTTCGAT', 'check left primer seq 2' );
is( $results->[1]->right_primer->sequence, 'GAATATTCCGCTGTCATTTCTGG', 'check right primer seq 2' );

#print Dumper( $results );

unlink( './int_1_primer3.out' );
