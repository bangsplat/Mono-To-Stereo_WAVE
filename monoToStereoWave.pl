#!/usr/bin/perl

use strict;
use Getopt::Long;
use Time::localtime;

#
# monoToStereoWave.pl
# version 0.92
#
# take two mono WAVE files and create a stereo WAVE file
#
# Version History
# version 0
# 	development
# version 0.9
# 	first working version
# 	added progress reporting
# version 0.91
# 	updated to work with blocks of samples
# version 0.92
# 	fixed Windows compatibility issue
# 

my ( $left_param, $right_param, $output_param, $block_param, $time_param, $progress_param );
my ( $help_param, $version_param, $debug_param, $test_param );
my ( $left_fh, $right_fh, $output_fh );
my ( $left_data_buffer, $right_data_buffer, $output_data_buffer );
my ( $left_sr, $right_sr, $left_bd, $right_bd, $left_nc, $right_nc );
my ( $left_length, $right_length );
my ( $wav_header, $raw_size, $chunk_size );
my ( $sub_chunk_1_size, $audio_format, $num_channels, $sample_rate );
my ( $bits_per_sample, $block_align, $byte_rate );
my ( $input_io_size, $output_io_size, $done, $bytes_read );
my ( $number_of_samples, $i, $j, $perc, $prev_perc );
my ( $start_time, $stop_time, $total_time );
my ( $bytes_per_sample, $bytes_in_block );

GetOptions(	'left=s'		=>	\$left_param,
			'right=s'		=>	\$right_param,
			'output|o=s'	=>	\$output_param,
			'block|b=n'		=>	\$block_param,
			'time|t!'		=>	\$time_param,
			'progress|p!'	=>	\$progress_param,
			'help|?'		=>	\$help_param,
			'version'		=>	\$version_param,
			'debug!'		=>	\$debug_param,
			'test!'			=>	\$test_param );

if ( $debug_param ) {
	print "DEBUG: passed parameters\n";
	print "\$left_param: $left_param\n";
	print "\$right_param: $right_param\n";
	print "\$output_param: $output_param\n";
	print "\$block_param: $block_param\n";
	print "\$time_param: $time_param\n";
	print "\$progress_param: $progress_param\n";
	print "\$help_param: $help_param\n";
	print "\$version_param: $version_param\n";
	print "\$debug_param: $debug_param\n";
	print "\$test_param: $test_param\n\n";
}

if ( $help_param ) {
	print <<'EOT';
monoToStereoWave.pl
Version 0.92

Take to mono WAVE files and create a stereo WAVE file

Supported parameters
	--left	<left_channel_file>
	--right <right_channel_file>
	--output <output_file>
		default is "stereo.wav"
	--block <block_size>
		default is 350,000 samples
	--[no]time
		report processing time
		default is false
	--help
		display help information
	--version
		display version information
EOT
	exit;
}

if ( $version_param ) {
	print "monoToStereoWave.pl version 0.92\n";
	exit;
}

if ( $left_param eq undef ) { die "ERROR: no left channel specified\n"; }
if ( $right_param eq undef ) { die "ERROR: no right channel specified\n"; }
if ( $output_param eq undef ) { $output_param = "stereo.wav"; }
if ( $block_param eq undef ) { $block_param = 1000; }
if ( $time_param eq undef ) { $time_param = 1; }
if ( $progress_param eq undef ) { $progress_param = 1; }

if ( $debug_param ) {
	print "DEBUG: adjusted parameters\n";
	print "\$left_param: $left_param\n";
	print "\$right_param: $right_param\n";
	print "\$output_param: $output_param\n";
	print "\$block_param: $block_param\n";
	print "\$time_param: $time_param\n";
	print "\$progress_param: $progress_param\n";
	print "\$help_param: $help_param\n";
	print "\$version_param: $version_param\n";
	print "\$debug_param: $debug_param\n";
	print "\$test_param: $test_param\n\n";
}

$start_time = time();
if ( $debug_param ) { print "DEBUG: Start time: $start_time\n"; }

# open our input files
if ( $debug_param ) { print "DEBUG: opening input files\n"; }
open( $left_fh, "<", $left_param ) or die "Can't open file $left_param\n";
open( $right_fh, "<", $right_param ) or die "Can't open file $right_param\n";

binmode( $left_fh );
binmode( $right_fh );

# open our output file
if ( $debug_param ) { print "DEBUG: opening output file $output_param\n"; }
open( $output_fh, ">", $output_param ) or die "Can't open file $output_param\n";

binmode( $output_fh );

if ( ! is_valid_wave( $left_fh ) ) { die "ERROR: invalid WAVE file: $left_param\n"; }
if ( ! is_valid_wave( $right_fh ) ) { die "ERROR: invalid WAVE file: $right_param\n"; }

# get critical information about each and make sure they match
$left_sr = get_sampling_rate( $left_fh );
$right_sr = get_sampling_rate( $right_fh );
$left_bd = get_bit_depth( $left_fh );
$right_bd = get_bit_depth( $right_fh );
$left_nc = get_num_channels( $left_fh );
$right_nc = get_num_channels( $right_fh );

# queue up both input files to the start of the data chunk
$left_length = find_chunk( $left_fh, "data" );
$right_length = find_chunk( $right_fh, "data" );

if ( $debug_param ) {
	print "DEBUG: left_sr: $left_sr\n";
	print "DEBUG: right_sr: $right_sr\n";
	print "DEBUG: left_bd: $left_bd\n";
	print "DEBUG: right_bd: $right_bd\n";
	print "DEBUG: left_nc: $left_nc\n";
	print "DEBUG: right_nc: $right_nc\n";
	print "DEBUG: left_length: $left_length\n";
	print "DEBUG: right_length: $right_length\n";
}

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
	print "DEBUG: Sampling rate: $left_sr\n";
	print "DEBUG: Bit depth: $left_bd\n";
	print "DEBUG: Number of channels: $left_nc\n";
	print "DEBUG: Data length: $left_length\n";
}


# output

# calculate the length of the output data
$raw_size = $left_length + $right_length;
$chunk_size = $raw_size + 36;

print $output_fh "RIFF";
print $output_fh pack( 'L', $chunk_size );
print $output_fh "WAVE";

if ( $debug_param ) {
	print "DEBUG: raw_size: $raw_size\n";
	print "DEBUG: chunk_size: $chunk_size\n";
}

$sub_chunk_1_size = 16;
$audio_format = 1;
$num_channels = 2;
$sample_rate = $left_sr;
$bits_per_sample = $left_bd;
$block_align = ceil( $num_channels * int( $bits_per_sample / 8 ) );
$byte_rate = $sample_rate * $block_align;

if ( $debug_param ) {
	print "DEBUG: sub_chunk_1_size: $sub_chunk_1_size\n";
	print "DEBUG: audio_format: $audio_format\n";
	print "DEBUG: num_channels: $num_channels\n";
	print "DEBUG: sample_rate: $sample_rate\n";
	print "DEBUG: bits_per_sample: $bits_per_sample\n";
	print "DEBUG: block_align: $block_align\n";
	print "DEBUG: byte_rate: $byte_rate\n";
}

print $output_fh "fmt ";
print $output_fh pack( 'L', $sub_chunk_1_size );
print $output_fh pack( 'S', $audio_format );
print $output_fh pack( 'S', $num_channels );
print $output_fh pack( 'L', $sample_rate );
print $output_fh pack( 'L', $byte_rate );
print $output_fh pack( 'S', $block_align );
print $output_fh pack( 'S', $bits_per_sample );

print $output_fh "data";
print $output_fh pack( 'L', $raw_size );

# now for the data


### so what I really want to do here is to read in the input files by chunks
### (larger than a single sample, in any event)
### then interleave those into a buffer and write that out in a single chunk

# default block size seems to provide good performance
my $io_chunk_samples = $block_param;

# I/O size should be one input file sample
# basically, $left_bd / 8
# the same calculation as the above block_align

$bytes_per_sample = ceil( int( $left_bd / 8 ) );
$input_io_size = $bytes_per_sample * $io_chunk_samples;
$output_io_size = $input_io_size * 2;

if ( $debug_param ) {
	print "DEBUG: input_io_size: $input_io_size\n";
	print "DEBUG: output_io_size: $output_io_size\n";
}

# figure out how many samples there are
$number_of_samples = $raw_size / $block_align;
if ( $debug_param ) {
	print "DEBUG: number_of_samples: $number_of_samples\n";
}

$i = 0;
$done = 0;

$prev_perc = -1;

while ( ! $done ) {
	$bytes_read = read( $left_fh, $left_data_buffer, $input_io_size );
	if ( $debug_param ) { print "DEBUG: bytes_read (L): $bytes_read\n"; }
	if ( $bytes_read lt $input_io_size ) { $done = 1; }
	$bytes_read = read( $right_fh, $right_data_buffer, $input_io_size );
	if ( $debug_param ) { print "DEBUG: bytes_read (R): $bytes_read\n"; }
	if ( $bytes_read lt $input_io_size ) { $done = 1; }

	if ( $progress_param ) {

		$i += $io_chunk_samples;
		$perc = ( int( ( $i / $number_of_samples ) * 1000 ) / 10 );		# figure out completeness
		if ( $perc > 100 ) { $perc = 100; }								# don't go over 100%
		if ( $perc ne $prev_perc ) { print "progress: $perc% \n"; }		# display percentage if changed
	
		$prev_perc = $perc;
	
		if ( $debug_param ) { print "DEBUG: progress: sample $i ($perc%)\n"; }
	}
	
	$output_data_buffer = "";	# clear the output buffer
	$bytes_in_block = $bytes_read / $bytes_per_sample;
	for ( $j = 0; $j < $bytes_in_block; $j++ ) {
		$output_data_buffer .= substr( $left_data_buffer, ( $j * $bytes_per_sample ), $bytes_per_sample );
		$output_data_buffer .= substr( $right_data_buffer, ( $j * $bytes_per_sample ), $bytes_per_sample );
	}
	
	print $output_fh $output_data_buffer;
}

if ( $debug_param ) { print "\n"; }

# clean up - close our files
if ( $debug_param ) { print "DEBUG: closing files\n"; }
clean_up();

if ( $debug_param ) { print "DEBUG: all done!\n"; }

$stop_time = time();
if ( $debug_param ) { print "DEBUG: Stop time: $start_time\n"; }
$total_time = $stop_time - $start_time;
if ( $time_param ) { print "DEBUG: Processing time: $total_time seconds\n"; }

# subroutines

# ceil()
# my quick-and-dirty version of the POSIX function
# because the POSIX module seems to cause issues here for some reason
sub ceil {
	my $input_value = shift;
	my $output_value = int( $input_value );
	if ( ( $input_value - $output_value ) > 0 ) { $output_value++; }
	return( $output_value );
}

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
	if ( $fmt_size == 0 ) { return( 0 ); }		# make sure there is a fmt  chunk
	
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
	if ( $fmt_size == 0 ) { return( 0 ); }		# make sure there is a fmt  chunk
	
	my $result = read( $fh, $header, $fmt_size );
	if ( $result == undef ) { return( 0 ); }
	
	return( long_value( substr( $header, 4, 4 ) ) );
}

sub get_bit_depth {
	my $fh = @_[0];
	my $header;

	my $fmt_size = find_chunk( $fh, "fmt " );
	if ( $fmt_size == 0 ) { return( 0 ); }		# make sure there is a fmt  chunk
	
	my $result = read( $fh, $header, $fmt_size );
	if ( $result == undef ) { return( 0 ); }
	
	return( short_value( substr( $header, 14, 2 ) ) );
}

sub get_num_channels {
	my $fh = @_[0];
	my $header;

	my $fmt_size = find_chunk( $fh, "fmt " );
	if ( $fmt_size == 0 ) { return( 0 ); }		# make sure there is a fmt  chunk
	
	my $result = read( $fh, $header, $fmt_size );
	if ( $result == undef ) { return( 0 ); }
	
	return( short_value( substr( $header, 2, 2 ) ) );
}

sub clean_up {
	close( $left_fh );
	close( $right_fh );
	close( $output_fh );
}



