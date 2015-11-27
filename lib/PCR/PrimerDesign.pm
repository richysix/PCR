## no critic (RequireUseStrict, RequireUseWarnings, RequireTidyCode)
package PCR::PrimerDesign;

## use critic

# ABSTRACT: PrimerDesign - object used to design PCR primer pairs

use namespace::autoclean;
use Moose;
use Moose::Util::TypeConstraints;
use autodie;
use Carp;
use Bio::EnsEMBL::Registry;
use PCR::Primer3;

=method new

  Usage       : my $primer_design_object = PCR::PrimerDesign->new(
                    config_file => $config_file,
                );
  Purpose     : Constructor for creating PrimerDesign object
  Returns     : PCR::PrimerDesign object
  Parameters  : config_file => Str
  Throws      : If parameters are not the correct type
  Comments    : None

=cut

=method config_file

  Usage       : $primer->config_file;
  Purpose     : Getter/Setter for config_file attribute
  Returns     : Config File Name    => Str
  Parameters  : Config File Name    => Str
  Throws      :
  Comments    : Can not be undef

=cut

has 'config_file' => (
    is => 'ro',
    isa => 'Str',
);

=method cfg

  Usage       : $primer->cfg;
  Purpose     : Getter/Setter for cfg attribute
  Returns     : HashRef
  Parameters  : HashRef
  Throws      :
  Comments    : Created from parsing $self->config_file

=cut

has 'cfg' => (
    is => 'ro',
    isa => 'HashRef',
    builder => '_build_config',
    lazy => 1,
);

=method primer3adaptor

  Usage       : $primer->primer3adaptor;
  Purpose     : Getter/Setter for primer3adaptor attribute
  Returns     : HashRef
  Parameters  : HashRef
  Throws      :
  Comments    :

=cut

has 'primer3adaptor' => (
    is => 'ro',
    isa => 'PCR::Primer3',
    builder => '_build_adaptor',
    lazy => 1,
);

=method _build_config

  Usage       : $primer->_build_config;
  Purpose     : Getter/Setter for _build_config attribute
  Returns     : HashRef
  Parameters  : HashRef
  Throws      :
  Comments    :

=cut

sub _build_config {
    my ( $self, ) = @_;
    my $cfg;
    if( $self->config_file ){
        # check file exists
        if( !-e $self->config_file || !-f $self->config_file ||
           !-r $self->config_file || -z $self->config_file ){
            confess join(q{ }, 'Config file,', $self->config_file,
                            "either does not exist or isn't readable or is empty!" ), "\n";
        }
        # open config file and parse
        open my $cfg_fh, '<', $self->config_file;
        while( <$cfg_fh> ) {
            next if /^\s*\#/; # skip comments
            $_ =~ s/[\n\r]//g;
            next unless $_ =~ m/^(.+)\t(.+)$/; # key-value pair
            my ($k, $v) = ($1, $2);
            $cfg->{ $k } = $v;
        }
        close ( $cfg_fh );
    }
    else{
        die "Primer3 config file must be set!: $!\n";
    }
    return $cfg;
};

=method _build_adaptor

  Usage       : $primer->_build_adaptor;
  Purpose     : Getter/Setter for _build_adaptor attribute
  Returns     : HashRef
  Parameters  : HashRef
  Throws      :
  Comments    :

=cut

sub _build_adaptor {
    my ( $self ) = @_;
    my $primer3adaptor = Primers::Primer3->new($self->cfg);
    return $primer3adaptor;
}


=func design_primers

  Usage       : $targets = design_primers($targets, 'ext', '450-800', 6, 1, 1, 1, $vfa, $slice_adaptor, );
  Purpose     : Design PCR primers
  Returns     : Hashref of primers and settings
  Parameters  : Hashref of primers and settings
                Type of primers ( 'ext', 'int', 'hrm' )
                Size range of amplicon
                Primer3 settings
                Round of primer design
                Repeatmask flag
                Variationmask flag
                VariationFeature Adaptor
                Slice Adaptor
  Throws      :
  Comments    : None

=cut

sub design_primers {
    my ( $self, $targets, $type, $size_range, $settings, $round,
        $repeat_mask, $variation_mask, $vfa, $slice_adaptor ) = @_;

    # Create FASTA file for RepeatMasker
    my $amps = $self->fasta_for_repeatmask($targets, $type);
    if (scalar(@$amps)){
        if( $repeat_mask ){
            $targets = $self->repeatmask($targets, $type);
        }
        if( $variation_mask ){
            $targets = $self->variationmask( $targets, $type, $vfa, $slice_adaptor  );
        }

        #print Dumper( %{$targets} );

        my $primer3_file = $self->primer3adaptor->setAmpInput($amps, undef, undef, $size_range, $settings, $round, '.');
        my $int_primers  = $self->primer3adaptor->primer3($primer3_file, $type . '_' . $settings . '_primer3.out');

        if( $int_primers ){
            foreach my $primer (sort {$a->amplicon_name cmp $b->amplicon_name
                                      || $a->pair_penalty <=> $b->pair_penalty
                                      || $a->product_size <=> $b->product_size } @{ $int_primers }) {
                my $id = $primer->amplicon_name;
                #print STDERR join("\t",
                #    $id,
                #    $targets->{$id}->{$type . '_start'} + $primer->left_primer->index_pos,
                #    $targets->{$id}->{$type . '_start'} + $primer->left_primer->index_pos + $primer->product_size - 1,
                #    $primer->variants_in_pcr_product,
                #), "\n";

                if ($primer->left_primer->seq && $primer->right_primer->seq
                    && !defined $targets->{$id}->{$type . '_primers'}) {
                        $primer->type( $type );
                        $targets->{$id}->{$type . '_primers'}  = $primer unless defined $targets->{$id}->{$type . '_primers'};
                        $targets->{$id}->{$type . '_round'}    = $round;
                    #next if $type eq 'hrm';
                    if( $targets->{$id}->{target}->strand eq '1' ){
                        # start and end
                        $targets->{$id}->{$type . '_start'}    = $targets->{$id}->{$type . '_start'} + $primer->left_primer->index_pos;
                        $targets->{$id}->{$type . '_end'}      = $targets->{$id}->{$type . '_start'} + ( $primer->product_size - 1 );

                        # left primer start and end
                        $targets->{$id}->{$type . '_primers'}->left_primer->seq_region_start( $targets->{$id}->{$type . '_start'} );
                        $targets->{$id}->{$type . '_primers'}->left_primer->seq_region_end( $targets->{$id}->{$type . '_start'} +
                                                                ( $targets->{$id}->{$type . '_primers'}->left_primer->length - 1 ) );
                        $targets->{$id}->{$type . '_primers'}->left_primer->seq_region_strand( '1' );

                        # right primer start and end
                        $targets->{$id}->{$type . '_primers'}->right_primer->seq_region_start(
                            ( $targets->{$id}->{$type . '_end'} -
                                ($targets->{$id}->{$type . '_primers'}->right_primer->length - 1) ) );
                        $targets->{$id}->{$type . '_primers'}->right_primer->seq_region_end( $targets->{$id}->{$type . '_end'} );
                        $targets->{$id}->{$type . '_primers'}->right_primer->seq_region_strand( '-1' );

                    }
                    if( $targets->{$id}->{target}->strand eq '-1' ){
                        # start and end
                        $targets->{$id}->{$type . '_end'}    = $targets->{$id}->{$type . '_end'} - $primer->left_primer->index_pos;
                        $targets->{$id}->{$type . '_start'}      = $targets->{$id}->{$type . '_end'} - ( $primer->product_size - 1 );

                        # left primer start and end
                        $targets->{$id}->{$type . '_primers'}->left_primer->seq_region_end( $targets->{$id}->{$type . '_end'} );
                        $targets->{$id}->{$type . '_primers'}->left_primer->seq_region_start( $targets->{$id}->{$type . '_end'} -
                                                                ( $targets->{$id}->{$type . '_primers'}->left_primer->length - 1 ) );
                        $targets->{$id}->{$type . '_primers'}->left_primer->seq_region_strand( '-1' );

                        # right primer start and end
                        $targets->{$id}->{$type . '_primers'}->right_primer->seq_region_start( $targets->{$id}->{$type . '_start'} );
                        $targets->{$id}->{$type . '_primers'}->right_primer->seq_region_end( $targets->{$id}->{$type . '_start'} +
                                                                ( $targets->{$id}->{$type . '_primers'}->right_primer->length - 1 ) );
                        $targets->{$id}->{$type . '_primers'}->right_primer->seq_region_strand( '1' );

                    }

                    $targets->{$id}->{$type . '_primers'}->left_primer->primer_id(
                        join(":", $targets->{$id}->{target}->chr || '',
                        join("-", $targets->{$id}->{$type . '_primers'}->left_primer->seq_region_start,
                            $targets->{$id}->{$type . '_primers'}->left_primer->seq_region_end, ),
                        $targets->{$id}->{$type . '_primers'}->left_primer->seq_region_strand )
                    );
                    $targets->{$id}->{$type . '_primers'}->right_primer->primer_id(
                        join(":", $targets->{$id}->{target}->chr || '',
                        join("-", $targets->{$id}->{$type . '_primers'}->right_primer->seq_region_start,
                            $targets->{$id}->{$type . '_primers'}->right_primer->seq_region_end, ),
                        $targets->{$id}->{$type . '_primers'}->right_primer->seq_region_strand )
                    );

                    $targets->{$id}->{$type . '_primers'}->pair_id(
                    join(":", $targets->{$id}->{target}->chr || '',
                                join("-", $targets->{$id}->{$type . '_start'}, $targets->{$id}->{$type . '_end'}, ),
                                $targets->{$id}->{target}->strand || '1',
                                $targets->{$id}->{$type . '_round'}, )
                    );

                }
            }
        }
    }
    return $targets;
}

=func fasta_for_repeatmask

  Usage       : $targets = $self->fasta_for_repeatmask($targets, 'ext', );
  Purpose     : Produce fasta file for repeatmasking sequence
  Returns     : ArrayRef
  Parameters  : Hashref of primers and settings
                Type of primers ( 'ext', 'int', 'hrm' )
  Throws      :
  Comments    : None

=cut

sub fasta_for_repeatmask {
    my ( $self, $targets, $type ) = @_;

    my $amp_array = [];

    open my $fasta_fh, '>',  'RM_' . $type . '.fa';
    foreach my $id ( sort keys %$targets ) {
        if ( defined $targets->{$id}->{"${type}_amp"}
            && !defined $targets->{$id}->{"${type}_primers"} )
        {
            my $amp = $targets->{$id}->{"${type}_amp"};
            print {$fasta_fh} '>', $amp->[0], "\n", $amp->[1], "\n";
            push( @$amp_array, $amp );
        }
    }
    close($fasta_fh);
    return $amp_array;
}

=func repeatmask

  Usage       : $targets = $self->repeatmask($targets, 'ext', );
  Purpose     : Runs RepeatMasker
  Returns     : Hashref of primers and settings
  Parameters  : Hashref of primers and settings
                Type of primers ( 'ext', 'int', 'hrm' )
  Throws      :
  Comments    : None

=cut

sub repeatmask {
    my ($self, $targets, $type ) = @_;

    my $pid = system('/software/pubseq/bin/RepeatMasker -xsmall -int RM_' . $type . '.fa');

    if (-f 'RM_' . $type . '.fa.out') {
        open my $rm_fh, '<', 'RM_' . $type . '.fa.out' or die "Can't open RM_", $type, ".fa.out: $!\n";
        while (<$rm_fh>) {
            chomp;
            my @line = split(/\s+/, $_);
            next unless @line && $line[1] =~ m/^\d+$/; # Score
            my $id = $line[5]; # ID
            push @{ $targets->{$id}->{$type . '_amp'}[5] }, [ $line[6], $line[7] - $line[6] ]; # Start and end
        }
        close($rm_fh);
    }

    my @rmfile = (
        'RM_' . $type . '.fa',
        'RM_' . $type . '.fa.ref',
        'RM_' . $type . '.fa.out',
        'RM_' . $type . '.fa.cat',
        'RM_' . $type . '.fa.masked',
        'RM_' . $type . '.fa.tbl',
        'RM_' . $type . '.fa.log',
        'RM_' . $type . '.fa.cat.all',
        'setdb.log',
    );
    unlink @rmfile;
    return $targets;
}

=func variationmask

  Usage       : $targets = $self->variationmask($targets, 'ext', $variation_feature_adaptor, $slice_adaptor, );
  Purpose     : Checks for SNPs and masks sequence
  Returns     : Hashref of primers and settings
  Parameters  : Hashref of primers and settings
                Type of primers ( 'ext', 'int', 'hrm' )
                Bio::EnsEMBL::Variation::DBSQL::VariationFeatureAdaptor
                Bio::EnsEMBL::DBSQL::SliceAdaptor
  Throws      :
  Comments    : None

=cut

sub variationmask {
    my ( $self, $targets, $type, $vfa, $slice_adaptor, ) = @_;

    foreach my $id (sort keys %$targets) {
        # get slice
        my $slice = $slice_adaptor->fetch_by_region( 'toplevel',
                    $targets->{$id}->{target}->chr, $targets->{$id}->{$type . '_start'},
                    $targets->{$id}->{$type . '_end'}, $targets->{$id}->{target}->strand, );
        #my $slice_length = $slice->length;
        my $vfs = $vfa->fetch_all_by_Slice($slice);
        my %vf_seen;
        foreach my $vf ( @{$vfs} ){
            #check if we've seen this before
            my $vf_key = $vf->seq_region_start() . '-' . $vf->seq_region_end() . '-' . $vf->allele_string();
            next if( exists $vf_seen{ $vf_key } );
            $vf_seen{ $vf_key } = 1;

            my $var = $vf->variation();
            if ($vf->var_class eq 'SNP') {
                push @{ $targets->{$id}->{$type . '_amp'}[5] },
                    [ $vf->start, $vf->end - ( $vf->start - 1) ];
            }
            elsif ($vf->var_class eq 'deletion') {
                # Ensure deletions don't extend out of slice
                my $start = $vf->seq_region_start();
                my $end   = $vf->seq_region_end();
                $start = 1 if $start < $targets->{$id}->{$type . '_start'};
                $end   = $vf->end if $end > $targets->{$id}->{$type . '_end'};
                push @{ $targets->{$id}->{$type . '_amp'}[5] },
                    [ $vf->start, $vf->end - ( $vf->start - 1) ];
            }
            elsif ($vf->var_class eq 'insertion') {
                my @alleles = split(/\//, $vf->allele_string());
                my $length = 0;
                foreach my $allele (@alleles) {
                    if ($allele ne '-' && length($allele) > $length) {
                        $length = length($allele);
                    }
                }
                push @{ $targets->{$id}->{$type . '_amp'}[5] },
                    [ $vf->start, $vf->start - ( $vf->end - 1 ) ];
            }
        }
    }

    return $targets;
}

=func print_nested_primers_header

  Usage       : $targets = $self->print_nested_primers_header();
  Purpose     : Returns header line for nested primers
  Returns     : Array
  Parameters  : None
  Throws      :
  Comments    : None

=cut

sub print_nested_primers_header {
    my ( $self, ) = @_;
    return join("\t",
    'chromosome', 'target_position', 'strand',
    'ext_amp_size', 'int_amp_size',
    'ext_round', 'int_round',
    'ext_pair_id', 'int_pair_id',
    'ext_left_id', 'ext_left_seq',
    'int_left_id', 'int_left_seq',
    'int_right_id', 'int_right_seq',
    'ext_right_id', 'ext_right_seq',
    'length1', 'tm1',
    'length2', 'tm2',
    'length3', 'tm3',
    'length4', 'tm4',
    ), "\n";
}

=func print_nested_primers_to_file

  Usage       : $targets = $self->print_nested_primers_to_file( $targets, $file_handle );
  Purpose     : prints nested primers to the supplied file handle
  Returns     : None
  Parameters  : Hashref of primers and settings
                FileHandle
  Throws      :
  Comments    : None

=cut

sub print_nested_primers_to_file {
    my ( $self, $targets, $primer_fh ) = @_;

    my $row = ['A', 'B', 'C', 'D', 'E', 'F', 'G', 'H',];
    my $col = [1..12];
    my ($coli, $rowi, $plate) = (0,0,1);

    foreach my $id (sort keys %$targets) {
        my $target_info = $targets->{ $id };
        if (defined $target_info->{ext_primers}) {
            if (defined $target_info->{int_primers}) {
                $target_info->{ext_primers}->pair_id(
                    join(":", $target_info->{target}->chr,
                                join("-", $target_info->{ext_start}, $target_info->{ext_end}, ),
                                $target_info->{target}->strand,
                                $target_info->{ext_round}, )
                    );
                $target_info->{int_primers}->pair_id(
                    join(":", $target_info->{target}->chr,
                                join("-", $target_info->{int_start}, $target_info->{int_end}, ),
                                $target_info->{target}->strand,
                                $target_info->{int_round}, )
                    );

                my ( $ext_left_id, $int_left_id, $int_right_id, $ext_right_id );
                if ($target_info->{target}->strand > 0) {
                    $target_info->{ext_primers}->left_primer_id(
                        join(":", $target_info->{target}->chr,
                        join("-", $target_info->{ext_start},
                        $target_info->{ext_start} + ( $target_info->{ext_primers}->left_primer->length - 1 ), ),
                        '1' )
                    );
                    $target_info->{int_primers}->left_primer_id(
                        join(":", $target_info->{target}->chr,
                        join("-", $target_info->{int_start},
                        $target_info->{int_start} + ( $target_info->{int_primers}->left_primer->length - 1 ), ),
                        '1' )
                    );
                    $target_info->{int_primers}->right_primer_id(
                        join(":", $target_info->{target}->chr,
                        join("-", ($target_info->{int_start} +
                                   ( $target_info->{int_primers}->product_size - 1 ) -
                                   ($target_info->{int_primers}->right_primer->length - 1)),
                        $target_info->{int_start} + ( $target_info->{int_primers}->product_size - 1 ), ),
                        '-1' )
                    );
                    $target_info->{ext_primers}->right_primer_id(
                        join(":", $target_info->{target}->chr,
                        join("-", ($target_info->{ext_start} +
                                   ( $target_info->{ext_primers}->product_size - 1 ) -
                                   ($target_info->{ext_primers}->right_primer->length - 1)),
                        $target_info->{ext_start} + ( $target_info->{ext_primers}->product_size - 1 ), ),
                        '-1' )
                    );
                }
                else{
                    $target_info->{ext_primers}->left_primer_id(
                        join(":", $target_info->{target}->chr,
                        join("-", ($target_info->{ext_start} +
                                   ( $target_info->{ext_primers}->product_size - 1 ) -
                                   ($target_info->{ext_primers}->left_primer->length - 1)),
                        $target_info->{ext_start} + ( $target_info->{ext_primers}->product_size - 1 ), ),
                        '-1' )
                    );
                    $target_info->{int_primers}->left_primer_id(
                        join(":", $target_info->{target}->chr,
                        join("-", ($target_info->{int_start} +
                                   ( $target_info->{int_primers}->product_size - 1 ) -
                                   ($target_info->{int_primers}->left_primer->length - 1)),
                        $target_info->{int_start} + ( $target_info->{int_primers}->product_size - 1 ), ),
                        '-1' )
                    );
                    $target_info->{int_primers}->right_primer_id(
                        join(":", $target_info->{target}->chr,
                        join("-", $target_info->{int_start},
                        $target_info->{int_start} + ( $target_info->{int_primers}->right_primer->length - 1 ), ),
                        '1' )
                    );
                    $target_info->{ext_primers}->right_primer_id(
                        join(":", $target_info->{target}->chr,
                        join("-", $target_info->{ext_start},
                        $target_info->{ext_start} + ( $target_info->{ext_primers}->right_primer->length - 1 ), ),
                        '1' )
                    );
                }

                print $primer_fh join("\t",
                    $target_info->{target}->chr,
                    join("-", $target_info->{spacer_target_start_g},
                         $target_info->{spacer_target_end_g} ),
                    $target_info->{target}->strand,
                    $target_info->{ext_primers}->product_size,
                    $target_info->{int_primers}->product_size,
                    $target_info->{ext_round},
                    $target_info->{int_round},
                    $target_info->{ext_primers}->pair_id,
                    $target_info->{int_primers}->pair_id,
                    $target_info->{ext_primers}->left_primer_id,
                    $target_info->{ext_primers}->left_primer->seq,
                    $target_info->{int_primers}->left_primer_id,
                    $target_info->{int_primers}->left_primer->seq,
                    $target_info->{int_primers}->right_primer_id,
                    $target_info->{int_primers}->right_primer->seq,
                    $target_info->{ext_primers}->right_primer_id,
                    $target_info->{ext_primers}->right_primer->seq,
                    $target_info->{ext_primers}->left_primer->length,
                    $target_info->{ext_primers}->left_primer->tm,
                    $target_info->{int_primers}->left_primer->length,
                    $target_info->{int_primers}->left_primer->tm,
                    $target_info->{int_primers}->right_primer->length,
                    $target_info->{int_primers}->right_primer->tm,
                    $target_info->{ext_primers}->right_primer->length,
                    $target_info->{ext_primers}->right_primer->tm,
                ), "\n";
            }
            else {
                print $primer_fh join("\t",
                    $target_info->{target}->chr,
                    join("-", $target_info->{spacer_target_start_g},
                         $target_info->{spacer_target_end_g} ),
                    $target_info->{target}->strand,
                    'No int primers',
                ), "\n";
            }
        }
        else {
            print $primer_fh join("\t",
                $target_info->{target}->chr,
                join("-", $target_info->{spacer_target_start_g},
                     $target_info->{spacer_target_end_g} ),
                $target_info->{target}->strand,
                'No ext primers',
            ), "\n";
        }
    }
}

=func print_nested_primers_to_file_and_plates

  Usage       : $targets = $self->print_nested_primers_to_file_and_plates( $targets, $file_handle, $plate_file_handle );
  Purpose     : prints nested primers to the supplied file handles
  Returns     : None
  Parameters  : Hashref of primers and settings
                FileHandle
                FileHandle
  Throws      :
  Comments    : None

=cut

sub print_nested_primers_to_file_and_plates {
    my ( $self, $targets, $primer_fh, $plate_fh ) = @_;

    my $row = ['A', 'B', 'C', 'D', 'E', 'F', 'G', 'H',];
    my $col = [1..12];
    my ($coli, $rowi, $plate) = (0,0,1);

    foreach my $id (sort keys %$targets) {
        my $target_info = $targets->{ $id };
        if (defined $target_info->{ext_primers}) {
            if (defined $target_info->{int_primers}) {
                $target_info->{ext_primers}->pair_id(
                    join(":", $target_info->{target}->chr,
                                join("-", $target_info->{ext_start}, $target_info->{ext_end}, ),
                                $target_info->{target}->strand,
                                $target_info->{ext_round}, )
                    );
                $target_info->{int_primers}->pair_id(
                    join(":", $target_info->{target}->chr,
                                join("-", $target_info->{int_start}, $target_info->{int_end}, ),
                                $target_info->{target}->strand,
                                $target_info->{int_round}, )
                    );

                my ( $ext_left_id, $int_left_id, $int_right_id, $ext_right_id );
                if ($target_info->{target}->strand > 0) {
                    $target_info->{ext_primers}->left_primer_id(
                        join(":", $target_info->{target}->chr,
                        join("-", $target_info->{ext_start},
                        $target_info->{ext_start} + ( $target_info->{ext_primers}->left_primer->length - 1 ), ),
                        '1' )
                    );
                    $target_info->{int_primers}->left_primer_id(
                        join(":", $target_info->{target}->chr,
                        join("-", $target_info->{int_start},
                        $target_info->{int_start} + ( $target_info->{int_primers}->left_primer->length - 1 ), ),
                        '1' )
                    );
                    $target_info->{int_primers}->right_primer_id(
                        join(":", $target_info->{target}->chr,
                        join("-", ($target_info->{int_start} +
                                   ( $target_info->{int_primers}->product_size - 1 ) -
                                   ($target_info->{int_primers}->right_primer->length - 1)),
                        $target_info->{int_start} + ( $target_info->{int_primers}->product_size - 1 ), ),
                        '-1' )
                    );
                    $target_info->{ext_primers}->right_primer_id(
                        join(":", $target_info->{target}->chr,
                        join("-", ($target_info->{ext_start} +
                                   ( $target_info->{ext_primers}->product_size - 1 ) -
                                   ($target_info->{ext_primers}->right_primer->length - 1)),
                        $target_info->{ext_start} + ( $target_info->{ext_primers}->product_size - 1 ), ),
                        '-1' )
                    );
                }
                else{
                    $target_info->{ext_primers}->left_primer_id(
                        join(":", $target_info->{target}->chr,
                        join("-", ($target_info->{ext_start} +
                                   ( $target_info->{ext_primers}->product_size - 1 ) -
                                   ($target_info->{ext_primers}->left_primer->length - 1)),
                        $target_info->{ext_start} + ( $target_info->{ext_primers}->product_size - 1 ), ),
                        '-1' )
                    );
                    $target_info->{int_primers}->left_primer_id(
                        join(":", $target_info->{target}->chr,
                        join("-", ($target_info->{int_start} +
                                   ( $target_info->{int_primers}->product_size - 1 ) -
                                   ($target_info->{int_primers}->left_primer->length - 1)),
                        $target_info->{int_start} + ( $target_info->{int_primers}->product_size - 1 ), ),
                        '-1' )
                    );
                    $target_info->{int_primers}->right_primer_id(
                        join(":", $target_info->{target}->chr,
                        join("-", $target_info->{int_start},
                        $target_info->{int_start} + ( $target_info->{int_primers}->right_primer->length - 1 ), ),
                        '1' )
                    );
                    $target_info->{ext_primers}->right_primer_id(
                        join(":", $target_info->{target}->chr,
                        join("-", $target_info->{ext_start},
                        $target_info->{ext_start} + ( $target_info->{ext_primers}->right_primer->length - 1 ), ),
                        '1' )
                    );
                }
                print $plate_fh join("\t",
                    $plate,
                    $row->[$rowi] . $col->[$coli],
                    $target_info->{ext_primers}->pair_id,
                    $target_info->{ext_primers}->left_primer_id,
                    $target_info->{ext_primers}->left_primer->seq,
                ), "\n";
                ( $rowi, $coli, $plate ) = $self->_increment_rows_columns($rowi, $coli, $plate);
                print $plate_fh join("\t",
                    $plate,
                    $row->[$rowi] . $col->[$coli],
                    $target_info->{int_primers}->pair_id,
                    $target_info->{int_primers}->left_primer_id,
                    $target_info->{int_primers}->left_primer->seq,
                ), "\n";
                ( $rowi, $coli, $plate ) = $self->_increment_rows_columns($rowi, $coli, $plate);
                print $plate_fh join("\t",
                    $plate,
                    $row->[$rowi] . $col->[$coli],
                    $target_info->{int_primers}->pair_id,
                    $target_info->{int_primers}->right_primer_id,
                    $target_info->{int_primers}->right_primer->seq,
                ), "\n";
                ( $rowi, $coli, $plate ) = $self->_increment_rows_columns($rowi, $coli, $plate);
                print $plate_fh join("\t",
                    $plate,
                    $row->[$rowi] . $col->[$coli],
                    $target_info->{ext_primers}->pair_id,
                    $target_info->{ext_primers}->right_primer_id,
                    $target_info->{ext_primers}->right_primer->seq,
                ), "\n";
                ( $rowi, $coli, $plate ) = $self->_increment_rows_columns($rowi, $coli, $plate);

                print $primer_fh join("\t",
                    $target_info->{target}->name,
                    $target_info->{ext_primers}->product_size,
                    $target_info->{int_primers}->product_size,
                    $target_info->{ext_round},
                    $target_info->{int_round},
                    $target_info->{ext_primers}->pair_id,
                    $target_info->{int_primers}->pair_id,
                    $target_info->{ext_primers}->left_primer_id,
                    $target_info->{ext_primers}->left_primer->seq,
                    $target_info->{int_primers}->left_primer_id,
                    $target_info->{int_primers}->left_primer->seq,
                    $target_info->{int_primers}->right_primer_id,
                    $target_info->{int_primers}->right_primer->seq,
                    $target_info->{ext_primers}->right_primer_id,
                    $target_info->{ext_primers}->right_primer->seq,
                    $target_info->{ext_primers}->left_primer->length,
                    $target_info->{ext_primers}->left_primer->tm,
                    $target_info->{int_primers}->left_primer->length,
                    $target_info->{int_primers}->left_primer->tm,
                    $target_info->{int_primers}->right_primer->length,
                    $target_info->{int_primers}->right_primer->tm,
                    $target_info->{ext_primers}->right_primer->length,
                    $target_info->{ext_primers}->right_primer->tm,
                ), "\n";
            }
            else {
                foreach ( 1..4 ){
                    print $plate_fh join("\t",
                        $plate,
                        $row->[$rowi] . $col->[$coli],
                        'EMPTY',
                        'EMPTY',
                        'EMPTY',
                    ), "\n";
                    ( $rowi, $coli, $plate ) = $self->_increment_rows_columns($rowi, $coli, $plate);
                }
                print $primer_fh join("\t",
                    $target_info->{target}->chr,
                    join("-", $target_info->{spacer_target_start_g},
                         $target_info->{spacer_target_end_g} ),
                    $target_info->{target}->strand,
                    'No int primers',
                ), "\n";
            }
        }
        else {
            foreach ( 1..4 ){
                print $plate_fh join("\t",
                    $plate,
                    $row->[$rowi] . $col->[$coli],
                    'EMPTY',
                    'EMPTY',
                    'EMPTY',
                ), "\n";
                ( $rowi, $coli, $plate ) = $self->_increment_rows_columns($rowi, $coli, $plate);
            }

            print $primer_fh join("\t",
                $target_info->{target}->chr,
                join("-", $target_info->{spacer_target_start_g},
                     $target_info->{spacer_target_end_g} ),
                $target_info->{target}->strand,
                'No ext primers',
            ), "\n";
        }
    }
}

=func print_hrm_primers_header

  Usage       : $targets = $self->print_hrm_primers_header();
  Purpose     : Returns header line for hrm primers
  Returns     : Array
  Parameters  : None
  Throws      :
  Comments    : None

=cut

sub print_hrm_primers_header {
    my ( $self, ) = @_;
    return join("\t",
    'id', 'chromosome', 'cut-site', 'strand',
    'hrm_amp_size',
    'hrm_round',
    'hrm_pair_id',
    'hrm_left_id', 'hrm_left_seq',
    'hrm_right_id', 'hrm_right_seq',
    'length1', 'tm1',
    'length2', 'tm2',
    'variants_in_product_all', 'variants_in_product_founder',
    ), "\n";
}

=func print_hrm_primers_to_file

  Usage       : $targets = $self->print_hrm_primers_to_file( $targets, $file_handle, $plate_file_handle, row_index, column_index, plate_number );
  Purpose     : prints hrm primers to the supplied file handles
  Returns     : None
  Parameters  : Hashref of primers and settings
                FileHandle
                FileHandle
  Throws      :
  Comments    : None

=cut

sub print_hrm_primers_to_file {
    my ( $self, $targets, $primer_fh, $plate_fh, $rowi, $coli, $plate ) = @_;

    my $row = ['A', 'B', 'C', 'D', 'E', 'F', 'G', 'H',];
    my $col = [1..12];
    $rowi = $rowi   ?   $rowi   :   0;
    $coli = $coli   ?   $coli   :   0;
    $plate = $plate   ?   $plate   :   1;

    foreach my $id (sort keys %$targets) {
        my $target_info = $targets->{$id};
        if (defined $target_info->{hrm_primers}) {
            my $primer_pair = $target_info->{hrm_primers};
            $target_info->{primers_designed} = 1;
            next if( $primer_pair->type ne 'hrm' );
            if( $primer_pair->primer_pair_id ){
                $primer_pair->pair_id( $primer_pair->primer_pair_id );
            }
            else{
                $primer_pair->pair_id(
                    join(":", $target_info->{target}->chr,
                                $target_info->{hrm_cut_site},
                                $target_info->{target}->strand,
                                $target_info->{hrm_round}, )
                    );
            }
            if ($target_info->{target}->strand > 0) {
                my $pcr_product_start = $target_info->{hrm_start} + $primer_pair->left_primer->index_pos;
                $primer_pair->left_primer_id(
                    join(":",
                        $target_info->{target}->chr,
                        join("-", $pcr_product_start,
                        $pcr_product_start + ( $primer_pair->left_primer->length - 1 ), ),
                        '1',
                    )
                );
                $primer_pair->right_primer_id(
                    join(":",
                        $target_info->{target}->chr,
                        join("-",  ( $pcr_product_start +
                        ( $primer_pair->product_size - 1 ) -
                        ( $primer_pair->right_primer->length - 1) ),
                        $pcr_product_start + ( $primer_pair->product_size - 1 ), ),
                        '-1',
                    )
                );
            }
            else {
                my $pcr_product_end = $target_info->{hrm_end} - $primer_pair->left_primer->index_pos;
                $primer_pair->left_primer_id(
                    join(":",
                        $target_info->{target}->chr,
                        join("-", $pcr_product_end -
                                   ($primer_pair->left_primer->length - 1),
                        $pcr_product_end ),
                        '-1',
                    )
                );
                $primer_pair->right_primer_id(
                    join(":",
                        $target_info->{target}->chr,
                        join("-", $pcr_product_end - ( $primer_pair->product_size - 1 ),
                            $pcr_product_end - ( $primer_pair->product_size - 1 ) +
                                ( $primer_pair->right_primer->length - 1 ), ),
                        '1',
                    )
                );
            }
            print $plate_fh join("\t",
                                $plate,
                                $row->[$rowi] . $col->[$coli],
                                $target_info->{target}->name,
                                $primer_pair->left_primer_id,
                                $primer_pair->left_primer->seq,
                            ), "\n";
            ( $rowi, $coli, $plate ) = $self->_increment_rows_columns($rowi, $coli, $plate);
            print $plate_fh join("\t",
                                $plate,
                                $row->[$rowi] . $col->[$coli],
                                $target_info->{target}->name,
                                $primer_pair->right_primer_id,
                                $primer_pair->right_primer->seq,
                            ), "\n";
            ( $rowi, $coli, $plate ) = $self->_increment_rows_columns($rowi, $coli, $plate);

            print $primer_fh join("\t",
                $targets->{$id}->{target}->name,
                $target_info->{target}->chr,
                $target_info->{hrm_cut_site},
                $target_info->{target}->strand,
                $primer_pair->product_size,
                $target_info->{hrm_round},
                $primer_pair->pair_id,
                $primer_pair->left_primer_id,
                $primer_pair->left_primer->seq,
                $primer_pair->right_primer_id,
                $primer_pair->right_primer->seq,
                $primer_pair->left_primer->length,
                $primer_pair->left_primer->tm,
                $primer_pair->right_primer->length,
                $primer_pair->right_primer->tm,
                $primer_pair->variants_in_pcr_product_all,
                $primer_pair->variants_in_pcr_product_founder,
            ), "\n";
        }
        else {
            print $plate_fh join("\t",
                                $plate,
                                $row->[$rowi] . $col->[$coli],
                                'EMPTY',
                                'EMPTY',
                                'EMPTY',
                            ), "\n";
            ( $rowi, $coli, $plate ) = $self->_increment_rows_columns($rowi, $coli, $plate);
            print $plate_fh join("\t",
                                $plate,
                                $row->[$rowi] . $col->[$coli],
                                'EMPTY',
                                'EMPTY',
                                'EMPTY',
                            ), "\n";
            ( $rowi, $coli, $plate ) = $self->_increment_rows_columns($rowi, $coli, $plate);

            print $primer_fh join("\t",
                $target_info->{target}->chr,
                $target_info->{hrm_cut_site},
                $target_info->{target}->strand,
                'No hrm primers',
            ), "\n";
        }
    }
    return ( $rowi, $coli, $plate );
}

=func _increment_rows_columns

  Usage       : $targets = $self->_increment_rows_columns( row_index, column_index, plate_number );
  Purpose     : Increment the plate indices column-wise
  Returns     : Row_index Int
                Column Index Int
                Plate number Int
  Parameters  : Row_index Int
                Column Index Int
                Plate number Int
  Throws      :
  Comments    : None

=cut

sub _increment_rows_columns {
    my ( $self, $rowi, $coli, $plate ) = @_;
    $rowi++;
    $coli++ if $rowi > 7;
    $rowi = 0 if $rowi > 7;
    $plate++ if $coli > 11;
    $coli = 0 if $coli > 11;
    return ( $rowi, $coli, $plate );
}

__PACKAGE__->meta->make_immutable;

1;
