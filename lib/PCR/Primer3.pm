## no critic (RequireUseStrict, RequireUseWarnings, RequireTidyCode)
package PCR::Primer3;
## use critic

# ABSTRACT: Primer3 - object used to run Primer3

use namespace::autoclean;
use Carp;
use File::Which;
use PCR::Primer;
use PCR::PrimerPair;
use Moose;

=method new

  Usage       : my $primer3_object = PCR::Primer3->new(
                    'cfg' => $config,
                );
  Purpose     : Constructor for creating Primer3 object
  Returns     : PCR::Primer3 object
  Parameters  : cfg     => HashRef
  Throws      : If parameters are not the correct type
  Comments    : None

=cut

=method cfg

  Usage       : $primer3_object->cfg;
  Purpose     : Getter/Setter for cfg attribute
  Returns     : HashRef
  Parameters  : HashRef
  Throws      : 
  Comments    : 

=cut

has 'cfg' => (
    is => 'ro',
    isa => 'Crispr::Config',
);

#################################################################
##  BUILD  ##
# This is run immediately after object creation.
# It checks that the Primer3 core and config directory exist.
#
#################################################################

sub BUILD {
    my ( $self, ) = @_;
    
    # check whether primer3 is installed and in the current path
    my $primer3_path = which( 'primer3_core' );
    if( !$primer3_path ){
        # try and find it via config or ENV variable
        if( defined $self->cfg->{'Primer3-bin'} &&
           -e $self->cfg->{'Primer3-bin'} && -x $self->cfg->{'Primer3-bin'} ){
            $primer3_path = $self->cfg->{'Primer3-bin'};
        }
        elsif( defined $ENV{PRIMER3_BIN} &&
           -e $ENV{PRIMER3_BIN} && -x $ENV{PRIMER3_BIN} ){
            $primer3_path = $ENV{PRIMER3_BIN};
        }
    }
    if( !$primer3_path ){
        confess "Could not find primer3!\n";
    }
    else{
        $self->cfg->{'Primer3-bin'} = $primer3_path;
    }
    
    # check version
    my $version_check_cmd = $primer3_path . ' -h 2>&1 ';
    open my $primer3_pipe, '-|', $version_check_cmd;
    while( my $line = <$primer3_pipe> ){
        next if( $line !~ m/This\sis\sprimer3/xms );
        $line =~ m/release\s
                    (\d+)\.(\d+)\.(\d+) # capture digits of version number
                    /xms;
        if( $1 < 2 ){ confess "Primer3 needs to be at least version 2.0.0!\n" }
    }
    
    my $primer3_config_path = $primer3_path;
    $primer3_config_path =~ s/core/config\//;
    
    my $DEFAULT_PRIMER3_CONFIG_PATH = '/opt/primer3_config/';

    # check the path to primer config dir is defined and exists
    if( -e $primer3_config_path && -d $primer3_config_path &&
        -x $primer3_config_path ){
        
    }
    elsif( defined $self->cfg->{'Primer3-config'} &&
            -e $self->cfg->{'Primer3-config'} &&
            -d $self->cfg->{'Primer3-config'} &&
            -x $self->cfg->{'Primer3-config'} ){
        $primer3_config_path = $self->cfg->{'Primer3-config'};
    }
    elsif( defined $DEFAULT_PRIMER3_CONFIG_PATH &&
            -e $DEFAULT_PRIMER3_CONFIG_PATH &&
            -d $DEFAULT_PRIMER3_CONFIG_PATH &&
            -x $DEFAULT_PRIMER3_CONFIG_PATH ){
        $primer3_config_path = $DEFAULT_PRIMER3_CONFIG_PATH;
    }
    elsif( defined $ENV{PRIMER3_CONFIG} && -e $ENV{PRIMER3_CONFIG}
               && -d $ENV{PRIMER3_CONFIG} && -x $ENV{PRIMER3_CONFIG} ){
        $primer3_config_path = $ENV{PRIMER3_CONFIG};
    }
    else{
        confess join(q{ }, "Primer3 config directory,",
                $self->cfg->{'Primer3-config'},
                "does not exist or is not a directory or is not executable!", ), "\n";
    }
    
    $self->cfg->{'Primer3-config'} = $primer3_config_path;
}

=method setAmpInput

  Usage       : $primer3_object->setAmpInput;
  Purpose     : Produce input file for Primer3 containing target sequences and settings
  Returns     : Name of Primer3 input file => Str
  Parameters  : AmpInfo             => ArrayRef [ Amp_ID, Sequence,
                                            Left_Primer_Seq, Right_Primer_Seq,
                                            [ Target, Length ],
                                            [ Excluded_Region_Start, Length ],
                                            [ Included_Region_Start, Length],
                                            Product_Size_Range, ]
                Target Position     => Int
                Target Size         => Int
                Product Size Range  => Str
                Settings            => Int
                Design Round        => Int
                Output Directory    => Str
  Throws      : 
  Comments    : 

=cut

sub setAmpInput { #setAmpInput(@[id, seq], $target_position, $target_size, $product_size, $param_settings);
    #@amp=[id, seq, left_p_seq, right_p_seq,@targets[pos,length],@exluded[pos,length],(pos,length)]
    my $self = shift;
    my $ampinput = shift; # A ref to an Array of refs containing the ampid at 0 and the sequence at 1
    my $target_pos = shift;
    my $target_size = shift;
    my $product_size = shift;
    my $settings = shift;
    my $id = shift;
    my $out_dir = shift;
    my @params;
    #$id = $self->cfg->{'gene_id'} unless defined $id;
    my $file = $out_dir? "$out_dir/AmpForDesign_${id}_$settings.txt" : $self->cfg->{'exp-path'} . $self->cfg->{'tmp-path'}."AmpForDesign_$id"."_$settings.txt";
    open my $out_fh, '>', $file or die "can't open $file: $!\n";
    push @params, join("=", 'PRIMER_THERMODYNAMIC_PARAMETERS_PATH',
                            $self->cfg->{'Primer3-config'} ) . "\n";
    foreach my $param (keys %{$self->cfg}) {
        my $key = $param;
        $param =~ s/^(\d)\_// if $param =~ m/PRIMER\_/;
        if ($1 && $1 eq $settings) {
            $param = $param . '=' . $self->cfg->{$key} . "\n";
            push(@params, $param) if $param =~ m/^PRIMER\_/;
        }
    }
    print {$out_fh} join('', @params) if @params;
    foreach my $input (@{$ampinput}) {
        if (!defined $input->[7]) {
            print {$out_fh} "PRIMER_PRODUCT_SIZE_RANGE=" . $product_size . "\n" if defined $product_size;
        } elsif (defined $product_size) {
            my ($start, $end) = split /-/, $product_size;
            print {$out_fh} "PRIMER_PRODUCT_SIZE_RANGE=" . ($start + $input->[7]) . '-' . ($end + $input->[7]) . "\n";
        }
        print {$out_fh} "SEQUENCE_ID=" . $input->[0] . "\n" if defined $input->[0];
        print {$out_fh} "SEQUENCE_TEMPLATE=" . $input->[1] . "\n";
        print {$out_fh} "PRIMER_LEFT_INPUT=" . $input->[2] ."\n" if defined $input->[2];
        print {$out_fh} "PRIMER_RIGHT_INPUT=" . $input->[3] ."\n" if defined $input->[3];
        print {$out_fh} "INCLUDED_REGION=" . $input->[6][0] . "," . $input->[6][1] . "\n" if defined $input->[6];
        
        if (defined $target_pos && defined $target_size) {
            print {$out_fh} "SEQUENCE_TARGET=" . $target_pos . "," . $target_size . "\n" if defined $target_pos && defined $target_size;
        } elsif (defined $input->[4]) {
            foreach (@{$input->[4]}) {
                print {$out_fh} "SEQUENCE_TARGET=" . $_->[0] . "," . $_->[1] . "\n";
            }
        }
        
        if (defined $input->[5]) {
            foreach (@{$input->[5]}) {
                print {$out_fh} "SEQUENCE_EXCLUDED_REGION=" . $_->[0] . "," . $_->[1] . "\n";
            }
        }
        
        print {$out_fh} "=\n";
    }
    close($out_fh);
    
    return $file;
}

=method primer3

  Usage       : $primer3_object->primer3( $input_file, $output_file );
  Purpose     : Subroutine to run primer3
  Returns     : Primer Pairs        => ArrayRef of PCR::PrimerPair objects
  Parameters  : Primer3 Input File  => Str
                Primer3 Output File => Str
  Throws      : 
  Comments    : 

=cut

sub primer3 { # primer3($file);
    my $self = shift;
    my $file = shift;
    my $output = shift;
    my $primer3_cmd = $self->cfg->{'Primer3-bin'} . " -strict_tags < $file";
    my $pid = open my $primer_pipe, '-|', $primer3_cmd;
    my $results = [];
    my $record = 0;
    my $text;
    my $result = {};
    my $c = 0;
    my $nc = 0;
    my ($seq_id, $target, $ex_region, $explain_left, $explain_right, $explain_pair, $size_range);
    while (<$primer_pipe>) {
        $text .= $_;
        chomp;
        
        my $param = $_;
        if ($param =~ m/\_(\d+)\w*\=/) {
            $nc = $1;
            $param =~  s/\_(\d+)//;
        }
        
        if ($c ne $nc || $param =~ m/^\=$/) {
            $result->{PAIR}{amplicon_name} = $seq_id if defined $seq_id;
            $result->{PAIR}{target} = $target if defined $target;
            $result->{PAIR}{excluded_regions} = $ex_region if defined $ex_region && scalar(@$ex_region) > 0;
            $result->{LEFT}{explain} = $explain_left if defined $explain_left;
            $result->{RIGHT}{explain} = $explain_right if defined $explain_right;
            $result->{PAIR}{explain} = $explain_pair if defined $explain_pair;
            $result->{PAIR}{product_size_range} = $size_range if defined $size_range;
            $result->{LEFT}{sequence} = $result->{LEFT}{input} if !defined $result->{LEFT}{sequence};
            $result->{RIGHT}{sequence} = $result->{RIGHT}{input} if !defined $result->{RIGHT}{sequence};
            if ($record) {
                $result->{PAIR}{left_primer} = PCR::Primer->new($result->{LEFT});
                $result->{PAIR}{right_primer} = PCR::Primer->new($result->{RIGHT});
                my $pair = PCR::PrimerPair->new($result->{PAIR});
                push(@$results, $pair);
                $result = {};
            }
            $c = $nc;
            if ($param =~ m/^\=$/) {
                $record = 0;
                $ex_region = undef;
                $target = undef;
                $seq_id = undef;
                $explain_left = undef;
                $explain_right = undef;
                $explain_pair = undef;
                $size_range = undef;
            }
        } elsif ($param =~ m/SEQUENCE_ID\=(.+)/) {
                $seq_id = $1;
                $record = 1; 
        } elsif ($param =~ m/^SEQUENCE/) {
            $record = 1;
        }
        
        if ($param =~ m/PRIMER_PRODUCT_SIZE_RANGE\=(.+)/) {
            $size_range = $1;
        } elsif ($param =~ m/PRIMER\_(\w+)\_EXPLAIN\=(.+)/) {
            $explain_left = $2 if $1 eq "LEFT";
            $explain_right = $2 if $1 eq "RIGHT";
            $explain_pair = $2 if $1 eq "PAIR";
        } elsif ($param =~ m/^TARGET\=(.+)/ ) {
            $target = $1;
        } elsif ($param =~ m/^EXCLUDED_REGION\=(.+)/) {
            $ex_region = [] unless defined $ex_region;
            push(@$ex_region, $1);
        } elsif ($record && $c =~ m/^\d+$/ && $param !~ m/^SEQUENCE\=/ && $param !~ m/INPUT/ && $param =~ m/^PRIMER_PAIR_PRODUCT_SIZE\=(.+)$/) {
            $result->{PAIR}{product_size} = $1;
        } elsif ($record && $c =~ m/^\d+$/ && $param !~ m/^SEQUENCE\=/ && $param !~ m/INPUT/ && $param =~ m/^PRIMER_WARNING\=(.+)$/) {
            $result->{PAIR}{warnings} = $1;
        } elsif ($record && $c =~ m/^\d+$/ && $param !~ m/^SEQUENCE\=/ && $param =~ m/^PRIMER\_(LEFT|RIGHT|PAIR)\_*([\w\_]*)\=(.+)$/) {
            my ($p,$key,$value) = ($1,$2,$3);
            $key = $p."_".$key if $p eq "PAIR";
            if (!$key && defined $value) {
                my ($pos, $length) = split(",",$value);
                if (defined $pos && defined $length) {
                    $result->{$p}{index_pos} = $p eq "LEFT"? $pos : $pos - $length + 1;
                    $result->{$p}{length} = $length;
                }
            } else {
                $result->{$p}{lc($key)} = $value;
            }
        }
    }

    close($primer_pipe);
    unlink $file;
    if (defined $output) {
        open my $out_fh, '>>', $output;
        print {$out_fh} $text;
        close($out_fh);
    }
    return $results;
}

__PACKAGE__->meta->make_immutable;

1;

__END__
