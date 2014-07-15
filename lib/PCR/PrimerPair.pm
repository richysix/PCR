## no critic (RequireUseStrict, RequireUseWarnings, RequireTidyCode)
package PCR::PrimerPair;
## use critic

# ABSTRACT: PrimerPair object - object representing a pair of PCR primers

use PCR::Primer;
use namespace::autoclean;
use Moose;
use Moose::Util::TypeConstraints;

my %types = (
	ext => 1,
	int => 1,
    illumina => 1,
    illumina_tailed => 1,
	hrm => 1,
	flag => 1,
	flag_revcom => 1,
	ha => 1,
	ha_revcom => 1,
);
my $error_message = "PrimerPair:Type attribute must be one of " . join(q{, }, sort keys %types) . ".\n";

subtype 'PCR::PrimerPair::Type',
	as 'Str',
	where {
		my $ok = 0;
		$ok = 1 if( exists $types{ lc($_) } );
	},
	message { return $error_message; };

=method new

  Usage       : my $primer_pair = PCR::PrimerPair->new(
                    'pair_name' => '5:12345152-12345819:1:1',
                    'amplicon_name' => 'crRNA:5:12345678-12345700:1',
                    'target' => '701,23',
                    'explain' => 'considered 37, unacceptable product size 26, ok 11',
                    'product_size_range' => '500-1000',
                    'excluded_regions' => [ '651,122', '1282,29', ]
                    'product_size' => '668',
                    'left_primer' => $left_primer,
                    'right_primer' => $right_primer,
                    'type' => 'ext',
                    'pair_compl_end' => '0.00',
                    'pair_compl_any' => '3.00',
                    'pair_penalty' => '0.1303'
                );
  Purpose     : Constructor for creating PrimerPair objects
  Returns     : PCR::PrimerPair object
  Parameters  : pair_name           => Str
                amplicon_name       => Str
                target              => Str
                explain             => Str
                product_size_range  => Str
                excluded_regions    => ArrayRef
                product_size        => Int
                left_primer         => PCR::Primer
                right_primer        => PCR::Primer
                type                => Str
                pair_compl_end      => Num
                pair_compl_any      => Num
                pair_penalty        => Num
  Throws      : If parameters are not the correct type
  Comments    : None

=cut

=method pair_name

  Usage       : $primer->pair_name;
  Purpose     : Getter/Setter for pair_name attribute
  Returns     : Str
  Parameters  : None
  Throws      : 
  Comments    : 

=cut

has 'pair_name' => (
	is => 'rw',
	isa => 'Str',
);

=cut

=method amplicon_name

  Usage       : $primer->amplicon_name;
  Purpose     : Getter for amplicon_name attribute
  Returns     : Str
  Parameters  : None
  Throws      : If input is given
  Comments    : Can be undef

=cut

=cut

=method warnings

  Usage       : $primer->warnings;
  Purpose     : Getter for warnings attribute
  Returns     : Str (must be a valid DNA string)
  Parameters  : None
  Throws      : If input is given
  Comments    : 

=cut

=cut

=method target

  Usage       : $primer->target;
  Purpose     : Getter for target attribute
  Returns     : Str
  Parameters  : None
  Throws      : If input is given
  Comments    : 

=cut

=cut

=method explain

  Usage       : $primer->explain;
  Purpose     : Getter for explain attribute
  Returns     : Str
  Parameters  : None
  Throws      : If input is given
  Comments    : 

=cut

=cut

=method product_size_range

  Usage       : $primer->product_size_range;
  Purpose     : Getter for product_size_range attribute
  Returns     : Str
  Parameters  : None
  Throws      : If input is given
  Comments    : 

=cut

has [ 'amplicon_name', 'warnings', 'target', 'explain', 'product_size_range' ] => (
	is => 'ro',
	isa => 'Str',
);

=cut

=method excluded_regions

  Usage       : $primer->excluded_regions;
  Purpose     : Getter for excluded_regions attribute
  Returns     : ArrayRef
  Parameters  : None
  Throws      : If input is given
  Comments    : 

=cut

has 'excluded_regions' => (
	is => 'ro',
	isa => 'ArrayRef',
);

=cut

=method product_size

  Usage       : $primer->product_size;
  Purpose     : Getter for product_size attribute
  Returns     : Int
  Parameters  : None
  Throws      : If input is given
  Comments    : 

=cut

=cut

=method query_slice_start

  Usage       : $primer->query_slice_start;
  Purpose     : Getter for query_slice_start attribute
  Returns     : Int
  Parameters  : None
  Throws      : If input is given
  Comments    : 

=cut

=cut

=method query_slice_end

  Usage       : $primer->query_slice_end;
  Purpose     : Getter for query_slice_end attribute
  Returns     : Int
  Parameters  : None
  Throws      : If input is given
  Comments    : 

=cut

has [ 'product_size', 'query_slice_start', 'query_slice_end' ] => (
	is => 'ro',
	isa => 'Int',
);

=cut

=method left_primer

  Usage       : $primer->left_primer;
  Purpose     : Getter for left_primer attribute
  Returns     : PCR::Primer
  Parameters  : None
  Throws      : If input is given
  Comments    : 

=cut

has 'left_primer' => (
	is => 'ro',
	isa => 'PCR::Primer',
	handles => {
		left_primer_name => 'primer_name',
	}
);

=cut

=method right_primer

  Usage       : $primer->right_primer;
  Purpose     : Getter for right_primer attribute
  Returns     : PCR::Primer
  Parameters  : None
  Throws      : If input is given
  Comments    : 

=cut

has 'right_primer' => (
	is => 'ro',
	isa => 'PCR::Primer',
	handles => {
		right_primer_name => 'primer_name',
	}
);

=cut

=method type

  Usage       : $primer->type;
  Purpose     : Getter for type attribute
  Returns     : Str
  Parameters  : None
  Throws      : If input is given
  Comments    : Must be one of 	ext, int, illumina, illumina_tailed, hrm, flag, flag_revcom, ha, OR ha_revcom

=cut

has 'type' => (
	is => 'rw',
	isa => 'PCR::PrimerPair::Type',
);

=cut

=method pair_compl_end

  Usage       : $primer->pair_compl_end;
  Purpose     : Getter for pair_compl_end attribute
  Returns     : Num
  Parameters  : None
  Throws      : If input is given
  Comments    : 

=cut

=cut

=method pair_compl_any

  Usage       : $primer->pair_compl_any;
  Purpose     : Getter for pair_compl_any attribute
  Returns     : Num
  Parameters  : None
  Throws      : If input is given
  Comments    : 

=cut

=cut

=method pair_compl_penalty

  Usage       : $primer->pair_compl_penalty;
  Purpose     : Getter for pair_compl_penalty attribute
  Returns     : Num
  Parameters  : None
  Throws      : If input is given
  Comments    : 

=cut

has [ 'pair_compl_end', 'pair_compl_any', 'pair_penalty' ] => (
	is => 'ro',
	isa => 'Num',
);

=cut

=method primer_pair_summary

  Usage       : $primer->primer_pair_summary;
  Purpose     : Returns a summary about the primer pair
                Amplicon Name, Product Size, Left Primer Summary, Right Primer Summary
  Returns     : Array
  Parameters  : None
  Throws      : 
  Comments    : 

=cut

sub primer_pair_summary {
    my ( $self, ) = @_;
    my @info = (
		$self->amplicon_name,
		$self->product_size,
    );
	push @info, $self->left_primer->primer_summary;
	push @info, $self->right_primer->primer_summary;
	return @info;
}

=cut

=method primer_pair_info

  Usage       : $primer->primer_pair_info;
  Purpose     : Returns Information about the primer pair
                Amplicon Name, Pair Name, Type, Product Size,
                Left Primer Info, Right Primer Info
  Returns     : Array
  Parameters  : None
  Throws      : 
  Comments    : 

=cut

sub primer_pair_info {
    my ( $self, ) = @_;
    my @info = (
		$self->amplicon_name,
		$self->pair_name,
		$self->type,
		$self->product_size,
    );
	push @info, $self->left_primer->primer_info;
	push @info, $self->right_primer->primer_info;
	return @info;
}

__PACKAGE__->meta->make_immutable;

1;


__END__

=pod

=head1 NAME
 
PCR::PrimerPair - Object representing a PCR primer pair.
 
=head1 SYNOPSIS
 
    use <PCR::Primer_pair>;
    my $primer_pair = PCR::Primer_pair->new(
    	target_id => 32,
        talen_pair_id => 125,
        type => 'ext',
        left_primer => $left_primer,
        right_primer => $right_primer,
        left_primer_id => 1,
        right_primer_id => 2,
        plate_id => '001',
        product_size => 200,
        amplicon_name => 'ENSE02377374',
        primer_pair_adaptor => $mock_primer_ad,
    );
    
  
=head1 DESCRIPTION
 
Objects of this class represent a primer pair.
The object contains the objects for the two primers that make up the pair as well
as other information about the pair.

