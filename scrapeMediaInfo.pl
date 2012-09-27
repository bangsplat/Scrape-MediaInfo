#!/usr/bin/perl
use strict;	# Enforce some good programming rules

use Getopt::Long;
use Cwd;
use File::Find;
use File::stat;
use Time::localtime;

#
# scrapeMediaInfo.pl
#
# Collect MediaInfo output for media files
#
# version 0.1
# Created 2012-09-27
# Modified 2012-09-27
#
# Theron Trowbridge
# http://therontrowbridge.com
#
# Version History
# Version 0
# 	start
#
# Flags:
#
# --directory | -d
# Specifies starting directory
# Default is current working directory
#
# --[no]recurse | -[no]r
# Recursively search sub-folders
# Negated by prepending "no" (i.e., --norecurse or -nor)
# Default is recursive searching
#
# --output | -o
# Specifies file to output results to
# Default is a temp file in the starting directory
#
# --version
# Display version information
#
# --help | -?
# Displays help message
#
# --[no]debug
# Display debugging information
# Default is no debug mode
#
# --[no]test
# Test mode - display file names but do not process
# Default is no test mode
#

### Possible improvements
### hook up --output option to output results to a text file
### add --sidecar option (default true) to output sidecar files for every media file
### 	if no --output specified and --nosidecar (or if --output STDOUT) output to STDIO
### add user-definable list of extensions to process???
### force overwrite of all media files?
### user-definable output format (--Output=Text vs. --Output=XML)?

# These are useful for temp file naming
my @MONTHS = qw( 01 02 03 04 05 06 07 08 09 10 11 12 );
my @DAYS = qw( 00 01 02 03 04 05 06 07 08 09 10 11 12 13 14 15 16 17 18 19 20 21 22 23 24 25 26 27 28 29 30 31 );
my @HOURS = qw( 00 01 02 03 04 05 06 07 08 09 10 11 12 13 14 15 16 17 18 19 20 21 22 23 );
my @MINUTES = qw ( 00 01 02 03 04 05 06 07 08 09 10 11 12 13 14 15 16 17 18 19 20 21 22 23 24 25 26 27 28 29 30 31 32 33 34 35 36 37 38 39 40 41 42 43 44 45 46 47 48 49 50 51 52 53 54 55 56 57 58 59 60 );
my @SECONDS = qw( 00 01 02 03 04 05 06 07 08 09 10 11 12 13 14 15 16 17 18 19 20 21 22 23 24 25 26 27 28 29 30 31 32 33 34 35 36 37 38 39 40 41 42 43 44 45 46 47 48 49 50 51 52 53 54 55 56 57 58 59 60 );

# The following extensions are to be processed - all others will be ignored
my @EXTS = qw( mov mpg mpeg ts m2t mp4 m4v );

my ( $directory_param, $output_param, $recurse_param, $version_param, $help_param, $debug_param, $test_param );

GetOptions(	'directory|d=s'	=> \$directory_param,
			'output|o=s'	=>	\$output_param,
			'recurse|r!'	=> 	\$recurse_param,
			'version'		=>	\$version_param,
			'help|?'		=> 	\$help_param,
			'debug!'		=> 	\$debug_param,
			'test!'			=> 	\$test_param );

# If user asked for help, display help message and exit
if ( $help_param ) {
	print "scrapeMediaInfo.pl\n";
	print "verion 0.1\n";
	print "\n";
	print "Collect MediaInfo output for media files\n";
	print "\n";
	print "NOTE: MediaInfo CLI must be installed and in path\n";
	print "\n";
	print "--directory | -d <directory> - set starting directory\n";
	print "default is current working directory\n";
	print "\n";
	print "--output | -o <filename> - output to file\n";
	print "default is a temp file in the starting directory\n";
	print "\n";
	print "--[no]recurse | -[no]r - recursive directory search\n";
	print "search through subdirectories for WAV files to convert\n";
	print "default is recursive search\n";
	print "\n";
	print "--help | -? - help\n";
	print "displays this message\n";
	exit;
}

if ( $version_param ) {
	print "scrapeMediaInfo.pl version 0.1\n";
	exit;
}

if ( $debug_param ) {
	print "DEBUG: Passed Parameters:\n";
	print "directory_param: $directory_param\n";
	print "output_param: $output_param\n";
	print "recurse_param: $recurse_param\n";
	print "version_param: $recurse_param\n";
	print "help_param: $help_param\n";
	print "debug_param: $debug_param\n";
	print "test_param: $test_param\n";
}

# Set parameter defaults
if ( $directory_param eq undef ) { $directory_param = cwd; }	# Current working directory
if ( $output_param eq undef ) {
	my $tempdate = localtime()->year + 1900 . $MONTHS[localtime()->mon] . $DAYS[localtime()->mday] . $HOURS[localtime()->hour] . $MINUTES[localtime()->min] . $SECONDS[localtime()->sec];
	$output_param = $directory_param . "/media_info" . $tempdate . ".txt";
}
if ( $recurse_param eq undef ) { $recurse_param = 1; }		# True
if ( $debug_param eq undef ) { $debug_param = 0; }			# False
if ( $test_param eq undef ) { $test_param = 0; }			# False

if ( $debug_param ) {
	print "DEBUG: Adjusted Parameters:\n";
	print "directory_param: $directory_param\n";
	print "output_param: $output_param\n";
	print "recurse_param: $recurse_param\n";
	print "version_param: $recurse_param\n";
	print "help_param: $help_param\n";
	print "debug_param: $debug_param\n";
	print "test_param: $test_param\n";
}

chdir( $directory_param );	# Change to the target directory
find( \&doittoit, "." ); 		# Begin file filtering

sub doittoit {
	# process all files (no directories) in the starting directory
	# and sub-directories if recursion is on
	if ( ( $recurse_param || $File::Find::dir eq "." ) && ( ! -d ) ) {
	
		# get some information about the item
		#	Full path of item
		#	Full path of parent directory
		#	Branch (name of parent directory's parent directory - may be empty)
		#	Twig (name of parent directory)
		#	Leaf (name of file or directory)
		my ( $full_path, $parent_dir, $leaf_name, $twig_name, $branch_name, $work_space, $file_size );
		
		### add a couple items to this standard list?  extension?  base name?
		
		$full_path = $directory_param . "/" . $File::Find::name;	# Create full path
		$full_path =~ s/\\/\//g;			# Turn around any backwards slashes
		if ( -d ) { $full_path .= "/"; }	# Add slash to end of the path if it is a directory
		$full_path =~ s/\/.\//\//;			# Remove extra "/./"
		$full_path =~ s/\/\//\//g;			# Remove any duplicate slashes
				
		$parent_dir = $full_path;
		$parent_dir =~ s/\/$//g;			# Strip any trailing slash
		$parent_dir =~ s/\/([^\/]+)$//;		# Delete and remember anything after after the last non-empty slash
		$leaf_name = $1;
		
		$work_space = $parent_dir;
		$work_space =~ s/\/([^\/]+)$//g;	# Strip everything before the last slash (just the file name)
		$twig_name = $1;
		$work_space =~ s/\/([^\/]+)$//g;	# Strip everything before the last slash (just the parent directory)
		$branch_name = $1;
		
		### all of these are being done as s//g, which may not be right - should probably use m// instead
		
		my $output_name = $leaf_name . ".mediainfo.xml";
		if ( ismedia( $leaf_name ) ) {
			if ( !-e $output_name ) {
				if ( $debug_param ) { print "DEBUG: getting mediainfo for $leaf_name\n"; }
				system( "mediainfo --Output=XML \"$leaf_name\" > \"$output_name\"" );
			}
		}
	}
}


sub ismedia($) {
	my $filename = shift;
	$filename =~ m/.+\.([^\.]+$)/;
	foreach ( @EXTS ) { if ( $_ eq $1 ) { return( 1 ); } }
}
