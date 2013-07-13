#!/usr/bin/perl

my $fh;

my $input_file = @ARGV[0];

print "opening file $input_file\n";

open( $fh, "<", $input_file ) or die "Can't open file $input_file\n";

my $size = get_file_size( $fh );

print "\$size: $size\n";

sub get_file_size {
	my $file_handle = shift;
	print "\$file_handle: $file_handle\n";
	my $file_size = -s $file_handle;
	print "\$file_size: $file_size\n";
	return( $file_size );
}
