#!/usr/bin/env perl
# primer.t
use Test::More;
use Test::Exception;
use Data::Dumper;

my $tests = 0;
#plan tests => 1 + 18 + 2 + 18;

use PCR::Primer3;

# check it throws if primer3 version is less than 2.3.0
my $config_hash;
if( -e '/software/pubseq/bin/primer3-1.1.1/bin/primer3_core' ){
    $config_hash->{'Primer3-bin'} = '/software/pubseq/bin/primer3-1.1.1/bin/primer3_core';
    throws_ok{ $primer3_object = PCR::Primer3->new(cfg => $config_hash) }
        qr/Version\sof\sprimer3\smust\sbe\sat\sleast\s2.3.0!/, 'new called with primer3 version less than 2.3.0';
    $tests++;
}

# check config file and read/parse it
my $config_file = 'config/example_primer3.cfg';
if( !-e $config_file || !-f $config_file ||
   !-r $config_file || -z $config_file ){
    die join(q{ }, 'Config file,', $config_file,
                    "either does not exist or isn't readable or is empty!" ), "\n";
}
# open config file and parse
$config_hash = {};
open my $cfg_fh, '<', $config_file;
while( <$cfg_fh> ) {
    next if /^\s*\#/; # skip comments
    $_ =~ s/[\n\r]//g;
    next unless $_ =~ m/^(.+)\t(.+)$/; # key-value pair
    my ($k, $v) = ($1, $2);
    $config_hash->{ $k } = $v;
}
close ( $cfg_fh );

# check Primer3-Bin exists
my $skip;
if( exists $config_hash->{'Primer3-bin'} ){
    if( !-e $config_hash->{'Primer3-bin'} ){
        if( defined $ENV{PRIMER3_BIN} && -e $ENV{PRIMER3_BIN} ){
            $config_hash->{'Primer3-bin'} = $ENV{PRIMER3_BIN};
        }
        else{
            $skip = 1;
        }
    }
}
else{
    if( defined $ENV{PRIMER3_BIN} && -e $ENV{PRIMER3_BIN} ){
        $config_hash->{'Primer3-bin'} = $ENV{PRIMER3_BIN};
    }
    else{
        $skip = 1;
    }
}

# check primer3 config exists
if( exists $config_hash->{'Primer3-config'} ){
    if( !-e $config_hash->{'Primer3-config'} ||
        !-x $config_hash->{'Primer3-config'} ){
        if( defined $ENV{PRIMER3_CONFIG} && -e $ENV{PRIMER3_CONFIG} ){
            $config_hash->{'Primer3-config'} = $ENV{PRIMER3_CONFIG};
        }
        elsif( defined $ENV{PRIMER3_BIN}  && -e $ENV{PRIMER3_BIN} ){
            $config_hash->{'Primer3-config'} = $ENV{PRIMER3_BIN};
            $config_hash->{'Primer3-config'} =~ s/primer3_core/primer3_config\//;
        }
        else{
            $skip = 1;
        }
    }
}
else{
    if( defined $ENV{PRIMER3_CONFIG} && -e $ENV{PRIMER3_CONFIG} ){
        $config_hash->{'Primer3-config'} = $ENV{PRIMER3_CONFIG};
    }
    elsif( defined $ENV{PRIMER3_BIN}  && -e $ENV{PRIMER3_BIN} ){
        $config_hash->{'Primer3-config'} = $ENV{PRIMER3_BIN};
        $config_hash->{'Primer3-config'} =~ s/primer3_core/primer3_config\//;
    }
    else{
        $skip = 1;
    }
}


if( $skip ){
    warn "WARNING: Could not detect Primer3. Skipping Primer3 tests!\n",
        "Set Environment variables PRIMER3_BIN and PRIMER3_CONFIG to run these tests!\n";
}
else{
    # make a new primer3 object
    my $primer3_object = PCR::Primer3->new(
        cfg => $config_hash,
    );
    
    # 1 test
    isa_ok( $primer3_object, 'PCR::Primer3');
    $tests++;
    
    # test methods - 3 tests
    my @methods = qw( cfg setAmpInput primer3 );
    
    foreach my $method ( @methods ) {
        can_ok( $primer3_object, $method );
        $tests++;
    }
    
    # check type constraints - 1 tests
    throws_ok { PCR::Primer3->new( cfg => 'config_file' ) }
        qr/Validation failed/ms, 'method new called with string not a Hashref';
    $tests++;
    
    ## check method calls - 4 tests
    my $sequence = 'GTAAGCCGCGGCGGTGTGTGTGTGTGTGTGTGTTCTCCGTCATCTGTGTTCTGCTGAATGATGAGGACAGACGTGTTTCTCCAGCGGAGGAAGCGTAGAGATGTTCTGCTCTCCATCATCGCTCTTCTTCTGCTCATCTTCGCCATCGTTCATCTCGTCTTCTGCGCTGGACTGAGTTTCCAGGGTTCGAGTTCTGCTCGCGTCCGCCGAGACCTCGAGAATGCGAGTGAGTGTGTGCAGCCACAGTCGTCTGAGTTTCCTGAAGGATTCTTCACGGTGCAGGAGAGGAAAGATGGAGGA';
    my $seq2 = 'GTGTATGTAGCTGTACTGTGTTTCGATCTGAAGATCAGCGAGTACGTGATGCAGCGCTTCAGTCCATGCTGCTGGTGTCTGAAACCTCGCGATCGTGACTCAGGCGAGCAGCAGCCTCTAGTGGGCTGGAGTGACGACAGCAGCCTGCGGGTCCAGCGCCGTTCCAGAAATGACAGCGGAATATTCCAGGATGATTCTGGATATTCACATCTATCGCTCAGCCTGCACGGACTCAACGAAATCAGCGACGAGCACAAGAGTGTGTTCTCCATGCCGGATCACGATCTGAAGCGAATCCTG';
    
    my $amp = [ ['test_amp1', $sequence, undef, undef, [ [150,1] ], [ [14,20] ], undef, undef ],
                ['test_amp2', $seq2, undef, undef, [ [150,1] ], [ ], undef, undef ], ];
    my $file;
    ok( $file = $primer3_object->setAmpInput( $amp, undef, undef, '50-300', 1, 1, '.' ), 'run set amp input' );
    is( $file, './AmpForDesign_1_1.txt', 'check file name' );
    $tests+=2;
    #exit;
    
    my $results;
    ok( $results = $primer3_object->primer3( $file, 'int_1_primer3.out' ), 'run primer3' );
    isa_ok( $results, 'ARRAY', 'is results an ArrayRef' );
    $tests+=2;
    
    is( $results->[0]->amplicon_name, 'test_amp1', 'check amp name 1' );
    is( $results->[0]->pair_penalty, '1.777278', 'check pair penalty 1' );
    is( $results->[0]->explain, 'considered 1, ok 1', 'check explain 1' );
    is( $results->[0]->product_size_range, '50-300', 'check product size range 1' );
    is( $results->[0]->left_primer->sequence, 'CATCTGTGTTCTGCTGAATGATG', 'check left primer seq 1' );
    is( $results->[0]->right_primer->sequence, 'CTTCAGGAAACTCAGACGACTG', 'check right primer seq 1' );
    $tests+=6;

    is( $results->[1]->amplicon_name, 'test_amp2', 'check amp name 2' );
    is( $results->[1]->pair_penalty, '0.174062', 'check pair penalty 2' );
    is( $results->[1]->explain, 'considered 2, ok 2', 'check explain 2' );
    is( $results->[1]->product_size_range, '50-300', 'check product size range 2' );
    is( $results->[1]->left_primer->sequence, 'ATGTAGCTGTACTGTGTTTCGAT', 'check left primer seq 2' );
    is( $results->[1]->right_primer->sequence, 'GAATATTCCGCTGTCATTTCTGG', 'check right primer seq 2' );
    $tests+=6;
    
    #print Dumper( $results );
    
    unlink( './int_1_primer3.out' );
}

done_testing( $tests );


