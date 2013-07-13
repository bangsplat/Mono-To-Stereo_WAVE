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

### OK, now let's do a test - make sure we can find the data chunk of one input file
my $result = find_chunk( $left_fh, "data" );
print "data chunk size: $result\n";
###




# clean up - close our files
if ( $debug_param ) { print "DEBUG: closing files\n"; }
close( $left_fh );
close( $right_fh );
close( $output_fh );

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
