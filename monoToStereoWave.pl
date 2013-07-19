#!/usr/bin/perl

use strict;
use Getopt::Long;
use Time::localtime;

#
# monoToStereoWave.pl
#
# take two mono WAVE files and create a stereo WAVE file
#


my ( $left_param, $right_param, $output_param );
my ( $help_param, $version_param, $debug_param, $test_param );
my ( $left_fh, $right_fh, $output_fh );
my ( $left_data_buffer, $right_data_buffer, $output_data_buffer );
my ( $left_sr, $right_sr, $left_bd, $right_bd, $left_nc, $right_nc );
my ( $left_length, $right_length );


GetOptions(	'left=s'		=>	\$left_param,
			'right=s'		=>	\$right_param,
			'output|o=s'	=>	\$output_param,
			'help|?'		=>	\$help_param,
			'version'		=>	\$version_param,
			'debug!'		=>	\$debug_param,
			'test!'			=>	\$test_param );

if ( $debug_param ) {
	print "DEBUG: passed parameters\n";
	print "\$left_param: $left_param\n";
	print "\$right_param: $right_param\n";
	print "\$output_param: $output_param\n";
	print "\$help_param: $help_param\n";
	print "\$version_param: $version_param\n";
	print "\$debug_param: $debug_param\n";
	print "\$test_param: $test_param\n\n";
}

if ( $help_param ) {
	print <<'EOT';
monoToStereoWave.pl
Version 0

Take to mono WAVE files and create a stereo WAVE file

Supported parameters
	--left	<left_channel_file>
	--right <right_channel_file>
	--help
		display help information
	--version
		display version information
EOT
	exit;
}

if ( $version_param ) {
	print "monoToStereoWave.pl version 0\n";
	exit;
}

if ( $left_param eq undef ) { die "ERROR: no left channel specified\n"; }
if ( $right_param eq undef ) { die "ERROR: no right channel specified\n"; }
if ( $output_param eq undef ) { $output_param = "stereo.wav"; }

if ( $debug_param ) {
	print "DEBUG: adjusted parameters\n";
	print "\$left_param: $left_param\n";
	print "\$right_param: $right_param\n";
	print "\$output_param: $output_param\n";
	print "\$help_param: $help_param\n";
	print "\$version_param: $version_param\n";
	print "\$debug_param: $debug_param\n";
	print "\$test_param: $test_param\n\n";
}

# open our input files
if ( $debug_param ) { print "DEBUG: opening input files\n"; }
open( $left_fh, "<", $left_param ) or die "Can't open file $left_param\n";
open( $right_fh, "<", $right_param ) or die "Can't open file $right_param\n";

# open our output file
if ( $debug_param ) { print "DEBUG: opening output file $output_param\n"; }
open( $output_fh, ">", $output_param ) or die "Can't open file $output_param\n";

if ( ! is_valid_wave( $left_fh ) ) { die "ERROR: invalid WAVE file: $left_param\n"; }
if ( ! is_valid_wave( $right_fh ) ) { die "ERROR: invalid WAVE file: $right_param\n"; }

# get critical information about each and make sure they match
$left_sr = get_sampling_rate( $left_fh );
$right_sr = get_sampling_rate( $right_fh );
$left_bd = get_bit_depth( $left_fh );
$right_bd = get_bit_depth( $right_fh );
$left_nc = get_num_channels( $left_fh );
$right_nc = get_num_channels( $right_fh );
$left_length = find_chunk( $left_fh, "data" );
$right_length = find_chunk( $right_fh, "data" );

if ( $left_sr ne $right_sr ) {
	clean_up();
	die "ERROR: Sampling rates do not match\n";
}

if ( $left_bd ne $right_bd ) {
	clean_up();
	die "ERROR: Bit depths do not match\n";
}

if ( $left_nc ne $right_nc ) {
	clean_up();
	die "ERROR: Both files are not mono\n";
}

if ( $left_length ne $right_length ) {
	clean_up();
	die "ERROR: Files are not the same length\n";
}

if ( $debug_param ) {
	print "Sampling rate: $left_sr\n";
	print "Bit depth: $left_bd\n";
	print "Number of channels: $left_nc\n";
	print "Data length: $left_length\n";
}



#	my $data_size = find_chunk( $fh, "data" );


# clean up - close our files
if ( $debug_param ) { print "DEBUG: closing files\n"; }
clean_up();

if ( $debug_param ) { print "DEBUG: all done!\n"; }




# subroutines

#	short_value()
#	convert argument into little-endian unsigned short
sub short_value {
	return( unpack( "S<", $_[0] ) );
}

#	long_value()
#	convert argument into little-endian unsigned long
sub long_value {
	return( unpack( "L<", $_[0] ) );
}

# find_chunk( $fh $find_chunk_id )
# find specified RIFF chunk in the file handle $fh
# returns the size of the chunk data (as per the header)
# leaves file positioned at first byte of chunk data
sub find_chunk {
	my ( $result, $buffer, $result, $read_chunk_id, $read_chunk_size );
	my $fh = shift;
	my $find_chunk_id = shift;
	my $done = 0;
	
	seek( $fh, 12, 0 );			# skip past the end of the header
	
	while ( !$done ) {
		$result = read ( $fh, $buffer, 8 );
		if ( $result eq 0 ) {			# end of file
			seek ( $fh, 0, 0 );	# rewind file
			return( 0 );			# return 0, which will indicate an error
		}
		
		$read_chunk_id = substr( $buffer, 0, 4 );
		$read_chunk_size = long_value( substr( $buffer, 4, 4 ) );
		
		if ( $read_chunk_id eq $find_chunk_id ) { return( $read_chunk_size ); }	# return chunk size
		else { seek( $fh, $read_chunk_size, 1 ); }			# seek to next chunk		
	}
}


# is_valid_wave( $fh )
# check open file referenced by file handle $fh to make sure it is a valid WAVE file
sub is_valid_wave {
	my $fh = @_[0];
	my $file_size = -s $fh;
	my ( $header, $result );
	seek( $fh, 0, 0 );	# rewind the file
	$result = read( $fh, $header, 12 );
	if ( $result == undef ) { return( 0 ); }
	
	my $chunk_id = substr( $header, 0 , 4 );
	my $chunk_size = long_value( substr( $header, 4, 4 ) );
	my $format = substr( $header, 8, 4 );
	
	if ( $chunk_id ne "RIFF" ) { return( 0 ); }
#	if ( ( $chunk_size + 8 ) ne $file_size ) { return( 0 ) };	# this is really more of a warning than an error
	if ( $format ne "WAVE" ) { return( 0 ); }
	
	my $fmt_size = find_chunk( $fh, "fmt " );
	if ( $fmt_size != 16 ) { return( 0 ); }		# fmt  chunk should be 24 bytes long - 16 without the header
	
	$result = read( $fh, $header, $fmt_size );
	if ( $result == undef ) { return( 0 ); }
	
	# read WAVE header values
	my $audio_format = short_value( substr( $header, 0, 2 ) );
	my $num_channels = short_value( substr( $header, 2, 2 ) );
	my $sample_rate = long_value( substr( $header, 4, 4 ) );
	my $byte_rate = long_value( substr( $header, 8, 4 ) );
	my $block_align = short_value( substr( $header, 12, 2 ) );
	my $bits_per_sample = short_value( substr( $header, 14, 2 ) );
	
	# validate the various values
	if ( $audio_format ne 1 ) { return( 0 ); }		# audio format should be 1
	if ( $num_channels lt 1 ) { return( 0 ); }		# must have at least one channel
	if ( $sample_rate lt 1 ) { return( 0 ); }		# must have a positive sampling rate
	if ( $byte_rate ne ( $sample_rate * $block_align ) ) { return( 0 ); } 
	# byte rate should be sample_rate * block_align
	if ( $bits_per_sample lt 1 ) { return( 0 ); }	# must have a positive bit depth
	
	# bytes_per_sample should line up with bits_per_sample and block_align
	my $bytes_per_sample = int( $bits_per_sample / 8 );
	if ( ( $bits_per_sample % 8 ) ne 0 ) { $bytes_per_sample++; }
	my $bytes_per_sample_frame = $bytes_per_sample * $num_channels;
	if ( $bytes_per_sample_frame ne $block_align ) { return( 0 ); }
	
	my $data_size = find_chunk( $fh, "data" );
	if ( $data_size eq 0 ) { return( 0 ); }			# must have a data chunk

	# if we get here, everything is fine
	return( 1 );
}


sub get_sampling_rate {
	my $fh = @_[0];
	my $header;

	my $fmt_size = find_chunk( $fh, "fmt " );
	if ( $fmt_size != 16 ) { return( 0 ); }		# fmt  chunk should be 24 bytes long - 16 without the header
	
	my $result = read( $fh, $header, $fmt_size );
	if ( $result == undef ) { return( 0 ); }
	
	return( long_value( substr( $header, 4, 4 ) ) );
}

sub get_bit_depth {
	my $fh = @_[0];
	my $header;

	my $fmt_size = find_chunk( $fh, "fmt " );
	if ( $fmt_size != 16 ) { return( 0 ); }		# fmt  chunk should be 24 bytes long - 16 without the header
	
	my $result = read( $fh, $header, $fmt_size );
	if ( $result == undef ) { return( 0 ); }
	
	return( short_value( substr( $header, 14, 2 ) ) );
}

sub get_num_channels {
	my $fh = @_[0];
	my $header;

	my $fmt_size = find_chunk( $fh, "fmt " );
	if ( $fmt_size != 16 ) { return( 0 ); }		# fmt  chunk should be 24 bytes long - 16 without the header
	
	my $result = read( $fh, $header, $fmt_size );
	if ( $result == undef ) { return( 0 ); }
	
	return( short_value( substr( $header, 2, 2 ) ) );
}

sub clean_up {
	close( $left_fh );
	close( $right_fh );
	close( $output_fh );
}



