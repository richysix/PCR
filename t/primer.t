#!/usr/bin/env perl
# primer.t
use warnings; use strict;

use Test::More;
use Test::Exception;

plan tests => 1 + 18 + 2 + 18;

use PCR::Primer;

# make a new primer object
my $primer = PCR::Primer->new(
    primer_name => '5:2403050-2403073:-1',
    seq_region => '5',
    seq_region_start => 2403050,
    seq_region_end => 2403073,
    seq_region_strand => '1',
    sequence => 'ACGATGACAGATAGACAGAAGTCG',
    index_pos => 180,
    length => 24,
    self_end => 0.00,
    penalty => 0.23,
    self_any => 5.00,
    end_stability => 2.57,
    tm => 58.23,
    gc_percent => 45.5,
);

# 1 test
isa_ok( $primer, 'PCR::Primer');

# test methods - 18 tests
my @methods = qw( sequence primer_name seq_region seq_region_strand seq_region_start
    seq_region_end index_pos length self_end penalty
    self_any end_stability tm gc_percent seq
    primer_summary primer_info primer_posn
);

foreach my $method ( @methods ) {
    can_ok( $primer, $method );
}

# check type constraints - 2 tests
throws_ok { PCR::Primer->new( seq_region_strand => '2' ) }
    qr/Validation failed/ms, 'strand not 1 or -1';
throws_ok { PCR::Primer->new( sequence => 'ACGATAGATJGACGATA' ) }
    qr/Validation\sfailed./ms, 'not DNA';

# check method calls - 18 tests
is( $primer->sequence, 'ACGATGACAGATAGACAGAAGTCG', 'check primer sequence' );
is( $primer->primer_name, '5:2403050-2403073:-1', 'check primer name' );
is( $primer->seq_region, '5', 'check primer chr' );
is( $primer->seq_region_start, 2403050, 'check primer start' );
is( $primer->seq_region_end, 2403073, 'check primer end' );
is( $primer->seq_region_strand, '1', 'check primer strand' );
is( $primer->index_pos, 180, 'check primer index pos' );
is( $primer->length, 24, 'check primer length' );
is( $primer->self_end, 0.00, 'check primer self end' );
is( $primer->penalty, 0.23, 'check primer penalty' );
is( $primer->self_any, 5.00, 'check primer self_any' );
is( $primer->end_stability, 2.57, 'check primer end_stability' );
is( $primer->tm, 58.23, 'check primer tm' );
is( $primer->gc_percent, 45.5, 'check primer gc_percent' );
is( $primer->seq, 'ACGATGACAGATAGACAGAAGTCG', 'check primer seq' );
is( join(",", $primer->primer_summary), '5:2403050-2403073:-1,ACGATGACAGATAGACAGAAGTCG', 'check primer primer_summary' );
is( join(",", $primer->primer_info), '5:2403050-2403073:-1,ACGATGACAGATAGACAGAAGTCG,24,58.23,45.5', 'check primer primer_info' );
is( join(",", $primer->primer_posn), '5:2403050-2403073:1', 'check primer gc_percent' );


