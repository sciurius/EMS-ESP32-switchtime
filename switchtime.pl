#!/usr/bin/perl -w

# Author          : Johan Vromans
# Created On      : Thu Apr 26 20:39:52 2022
# Last Modified By: Johan Vromans
# Last Modified On: Thu Apr 28 20:57:18 2022
# Update Count    : 31
# Status          : Unknown, Use with caution!

################ Common stuff ################

use strict;
use warnings;

# Package name.
my $my_package = 'Sciurix';
# Program name and version.
my ($my_name, $my_version) = qw( switchtime 0.01 );

################ Command line parameters ################

use Getopt::Long 2.13;

# Command line options.
my $url = "http://emsgw1.squirrel.nl/api";
my $init;			# complete setup
my $verbose = 1;		# verbose processing

# Development options (not shown with -help).
my $debug = 0;			# debugging
my $trace = 0;			# trace (show process)
my $test = 0;			# test mode.

# Process command line options.
app_options();

# Post-processing.
$trace |= ($debug || $test);

################ Presets ################

my $TMPDIR = $ENV{TMPDIR} || $ENV{TEMP} || '/usr/tmp';

################ The Process ################

use LWP::UserAgent;
use HTTP::Headers;
use Time::HiRes qw( usleep );
use JSON::XS;
use Data::Dumper;

use constant POINTMAX => 41;		# 00 .. 41

my $pp = JSON::XS->new->utf8;
$pp->boolean_values( qw(false true) );

my @days = qw( mo tu we th fr sa su );
my $i = 0;
my %days = map { $_ => $i++ } @days; 

if ( $init ) {
    my $day = -1;
    my $sw = [];
    my @points;
    for ( $i = 0; $i < @ARGV; $i++ ) {
	$_ = $ARGV[$i];
	if ( exists $days{$_} ) {
	    if ( $day < 0 ) {
		$day = $days{$_};
		$sw = [];
	    }
	    else {
		for my $d ( $day .. $days{$_}-1 ) {
		    push( @points,
			  sprintf( "%s %s",
				   $days[$d], $_ ) ) for @$sw;
		}
		$day = $days{$_};
		$sw = [];
	    }
	}
	elsif ( /^(?:[01][0-9]|2[0-3]):[0-5][0-9]$/ ) {
	    if ( $i < @ARGV && $ARGV[$i+1] =~ /^t[1-4]$/i ) {
		push( @$sw, "$_ ".uc($ARGV[$i+1]) );
		$i++;
	    }
	    else {
		die("Time $_ must be followed by T1 .. T4\n");
	    }
	}
	else {
	    die("Input not understood: $_\n");
	}
    }
    for my $d ( $day .. @days-1 ) {
	push( @points,
	      sprintf( "%s %s",
		       $days[$d], $_ ) ) for @$sw;
    }
    for ( my $i = 0; $i < @points; $i++ ) {
	my $t = sprintf( "%02d %s", $i, $points[$i] );
	if ( $test ) {
	    printf( "$t\n" );
	}
	else {
	    warn( switchtime( substr($t,0,2), $t ) );
	}
    }
    unless ( $test ) {
	for ( my $i = @points; $i <= POINTMAX; $i++ ) {
	    my $t = sprintf( "%02d %s", $i, "not_set" );
	    switchtime( substr($t,0,2), $t );
	}
    }
}

elsif ( @ARGV ) {

    for ( @ARGV ) {
	s/\s+/ /g;
	die( "Invalid switchtime: $_\n" )
	  unless m/ ^ ( \d\d )
		    \s
		    (?: not_set
		        | (?: mo|tu|we|th|fr|sa|su)
			  \s
			  (?: [01][0-9] | 2[0-3] ) : [0-5][0-9]
			  \s
			  T[1-4] )
		      $/x
		&& $1 <= POINTMAX ;
	warn( switchtime( $1, $_ ), "\n" );
    }
}

else {
    my $notsets = 0;
    for ( my $n = 0; $n < POINTMAX; $n++ ) {
	my $value = switchtime($n);
	if ( $value =~ /not_set/ ) {
	    # Terminate on a series of 'not set'.
	    last if $notsets++ > 3;
	}
	else {
	    warn( $value, "\n" );
	    $notsets = 0;
	}
    }
}

# Always reset to first.
switchtime(0) unless $test;

################ Subroutines ################

my $ua;

sub switchtime {
    my ( $index, $value ) = @_;
    $value //= sprintf("%02d", $index);

    unless ( $ua ) {
	$ua = LWP::UserAgent->new;
	$ua->timeout(4);
	$ua->default_headers
	  ( HTTP::Headers->new
	    ( Content_Type => 'application/json',
#	      Authorization => 'bearer ' . $token,
	    ));
    }

    my $data = post( "$url/thermostat/hc1.switchtime1",
		     { value => $value } );

    for ( 0 .. 3 ) {
	# Prevent overflow the server.
	usleep(200000);

	$data = get("$url/thermostat/hc1.switchtime1");
	if ( substr( $data->{value}, 0, 2 ) == $index ) {
	    return $data->{value};
	}
    }
    warn( "Error $value: ", Dumper($data) );
}

sub get {
    my ( $url ) = @_;
    my $res = $ua->get($url);
    return $pp->decode($res->decoded_content) if $res->is_success;
    die( "=== $url ===\n", $res->status_line, "\n" );
}

sub post {
    my ( $url, $data ) = @_;
    my $res = $ua->post( $url, Content => $pp->encode($data) );
    return $pp->decode($res->decoded_content) if $res->is_success;
    die( "=== $url ===\n", $res->status_line, "\n" );
}

################ Subroutines ################

sub app_options {
    my $help = 0;		# handled locally
    my $ident = 0;		# handled locally
    my $man = 0;		# handled locally

    my $pod2usage = sub {
        # Load Pod::Usage only if needed.
        require Pod::Usage;
        Pod::Usage->import;
        &pod2usage;
    };

    # Process options.
    if ( @ARGV > 0 ) {
	GetOptions( init	=> \$init,
		    'ident'	=> \$ident,
		    'verbose+'	=> \$verbose,
		    'quiet'	=> sub { $verbose = 0 },
		    'trace'	=> \$trace,
		    'dry-run|test|n' => \$test,
		    'help|?'	=> \$help,
		    'man'	=> \$man,
		    'debug'	=> \$debug )
	  or $pod2usage->(2);
    }
    if ( $ident or $help or $man ) {
	print STDERR ("This is $my_package [$my_name $my_version]\n");
    }
    if ( $man or $help ) {
	$pod2usage->(1) if $help;
	$pod2usage->(VERBOSE => 2) if $man;
    }
}

__END__

################ Documentation ################

=head1 NAME

sample - skeleton for GetOpt::Long and Pod::Usage

=head1 SYNOPSIS

sample [options] [file ...]

 Options:
   --ident		shows identification
   --help		shows a brief help message and exits
   --man                shows full documentation and exits
   --verbose		provides more verbose information
   --quiet		runs as silently as possible

=head1 OPTIONS

=over 8

=item B<--help>

Prints a brief help message and exits.

=item B<--man>

Prints the manual page and exits.

=item B<--ident>

Prints program identification.

=item B<--verbose>

Provides more verbose information.
This option may be repeated to increase verbosity.

=item B<--quiet>

Suppresses all non-essential information.

=item I<file>

The input file(s) to process, if any.

=back

=head1 DESCRIPTION

B<This program> will read the given input file(s) and do someting
useful with the contents thereof.

=cut
