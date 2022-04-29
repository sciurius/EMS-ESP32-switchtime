#!/usr/bin/perl -w

# Author          : Johan Vromans
# Created On      : Thu Apr 26 20:39:52 2022
# Last Modified By: Johan Vromans
# Last Modified On: Fri Apr 29 10:43:43 2022
# Update Count    : 54
# Status          : Unknown, Use with caution!

################ Common stuff ################

use strict;
use warnings;

# Package name.
my $my_package = 'Sciurix';
# Program name and version.
my ($my_name, $my_version) = qw( switchtime 0.02 );

################ Command line parameters ################

use Getopt::Long 2.13;

# Command line options.
my $url = "http://emsgw1.squirrel.nl/api";
my $token;
my $init;			# complete setup
my $verbose = 1;		# verbose processing

# Development options (not shown with -help).
my $debug = 0;			# debugging
my $trace = 0;			# trace (show process)
my $test = 0;			# test mode.

# Process command line options.
app_options();

die("Invalud URL, must start with 'http:' and end with '/api'\n")
  unless $url =~ /^http:\/\/.+\/api$/;

# Post-processing.
$trace |= ($debug || $test);

################ Presets ################

my $TMPDIR = $ENV{TMPDIR} || $ENV{TEMP} || '/usr/tmp';

################ The Process ################

use LWP::UserAgent;
use HTTP::Headers;
use Time::HiRes qw( usleep );
use JSON::PP;			# or JSON::XS
use Data::Dumper;

use constant POINTMAX => 41;		# 00 .. 41

my $pp = JSON::PP->new->utf8;
$pp->boolean_values( qw(false true) );

my @days = qw( mo tu we th fr sa su );
my $i = 0;
my %days = map { $_ => $i++ } @days; 

if ( $init ) {
    die("--init requires arguments, first must be 'mo'\n")
      unless $ARGV[0] eq 'mo';

    my $day = -1;
    my $sw = [];
    my @points;

    for ( $i = 0; $i < @ARGV; $i++ ) {
	$_ = $ARGV[$i];

	# Day code.
	if ( exists $days{$_} ) {
	    if ( $day >= 0 ) {
		# Copy previous settings for inbetween days.
		for my $d ( $day .. $days{$_}-1 ) {
		    push( @points,
			  sprintf( "%s %s",
				   $days[$d], $_ ) ) for @$sw;
		}
	    }
	    $day = $days{$_};
	    $sw = [];
	}

	# Time specification (24 hr) plus preset.
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

    # Flush final day settings.
    for my $d ( $day .. @days-1 ) {
	push( @points,
	      sprintf( "%s %s",
		       $days[$d], $_ ) ) for @$sw;
    }

    # Process the switch points.
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
	# I'm not sure all need to be set. Probably a single
	# 'not-set' already terminates the list?
	for ( my $i = @points; $i <= POINTMAX; $i++ ) {
	    my $t = sprintf( "%02d %s", $i, "not_set" );
	    switchtime( substr($t,0,2), $t );
	}
    }
}

elsif ( @ARGV ) {		# modify individual points

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

else {				# no args, show all

    my $notsets = 0;
    for ( my $n = 0; $n < POINTMAX; $n++ ) {
	my $value = switchtime($n);
	if ( $value =~ /not_set/ ) {
	    # Terminate on a series of 'not set'.
	    # Probably one is enough?
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
	      $token ? ( Authorization => 'bearer ' . $token ) : (),
	    ));
    }

    # First we must select an entry.
    my $data = post( "$url/thermostat/hc1.switchtime1",
		     { value => $value } );

    # Then retrieve its value. May take a short while.
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

# Helper: get.
sub get {
    my ( $url ) = @_;
    my $res = $ua->get($url);
    return $pp->decode($res->decoded_content) if $res->is_success;
    die( "=== $url ===\n", $res->status_line, "\n" );
}

# Helper: post.
sub post {
    my ( $url, $data ) = @_;
    my $res = $ua->post( $url, Content => $pp->encode($data) );
    return $pp->decode($res->decoded_content) if $res->is_success;
    die( "=== $url ===\n", $res->status_line, "\n" );
}

################ Command line arguments ################

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
		    'url=s'	=> \$url,
		    'ident'	=> \$ident,
		    'verbose+'	=> \$verbose,
		    'quiet'	=> sub { $verbose = 0 },
		    'trace'	=> \$trace,
		    'dry-run|test|n' => \$test,
		    'help|?'	=> \$help,
		    'man'	=> \$man,
		    'debug'	=> \$debug )
	  or $pod2usage->( -exitval => 2, -verbose => 0 );
    }
    if ( $ident or $help or $man ) {
	print STDERR ("This is $my_package [$my_name $my_version]\n");
    }
    if ( $man or $help ) {
	$pod2usage->( -exitval => 0, -verbose => 0 ) if $help;
	$pod2usage->( -exitval => 0, -verbose => 2 ) if $man;
    }
}

################ Documentation ################

=head1 NAME

switchtime - inspect/modify thermostat switch times

=head1 SYNOPSIS

switchtime [options] [args ...]

 Options:
   --url=XXX		URL of the EMS-ESP gateway to the thermostat
   --token=XXX		Access token, if needed
   --init		completely replace all settings
   --dry-run -n		do not actually modify settings
   --ident		shows identification
   --help		shows a brief help message and exits
   --man                shows full documentation and exits
   --verbose		provides more verbose information
   --quiet		runs as silently as possible

=head1 OPTIONS

=over 8

=item B<--url=>I<XXX>

The URL of the EMS-ESP gateway to the thermostat.
The gateway needs to run EMS-ESP version  3.4.1 or later.

The URL should end with C</api>.

=item B<--token=>I<XXX>

Access token, if needed.
It will be passed as bearer in an C<Authorization> header.

=item B<--init>

Completely replace all settings by new values.

=item B<--dry-run>   B<-n>

Do not actually update the thermostat.

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

=item I<args>

Arguments. See below.

=back

=head1 DESCRIPTION

B<This program> has three functions.

One is to inspect the current switch times programmed in the thermostat.
For this, do not supply any arguments.

    $ switchtime
    00 mo 07:00 T4
    01 mo 22:00 T1
    02 tu 07:00 T4
    ...
    14 su 09:30 T4
    15 su 22:00 T1

Second is to modify individual switch times.
Specify the entries on the command line.

    $ switchtime "04 we 07:00 T4"
    04 we 07:00 T4

Finally, it can be used to completely reprogram the thermostat.
On the command line, speciy B<--init> and a series of day codes,
each followed by one or
more pairs of switch time (HH:MM) and preset (T1, .. T4).
Missing day settings will be copied from the preceding day.

    $ switchtime.pl --init mo 07:00 T2 22:00 T1 su 10:00 T2 22:30 T1
    00 mo 07:00 T2
    01 mo 22:00 T1
    02 tu 07:00 T2
    03 tu 22:00 T1
    ...same for we th fr sa ...
    12 su 10:00 T2
    13 su 22:30 T1

=head1 REQUIREMENTS

A suitable thermostat, accessible via an EMS-ESP gateway.

See https://github.com/emsesp/EMS-ESP32 .

=head1 INSTALL

Install the necessary modules:

    $ cpan LWP::UserAgent HTTP::Headers Time::HiRes JSON::PP

Copy the script C<switchtime.pl> to any convenient location that is in
your C<PATH> and make it executable. For example:

    $ cp switchtime.pl $HOME/bin/switchtime
    $ chmod 0755 $HOME/bin/switchtime

=head1 AUTHOR

Johan Vromans, C<< <jvromans AT squirrel DOT nl> >>

=head1 SUPPORT AND DOCUMENTATION

Development of this module takes place on GitHub:
https://github.com/sciurius/EMS-ESP32-switchtime.

You can find documentation for this module with the perldoc command.

    switchtime --manual

Please report any bugs or feature requests using the issue tracker on
GitHub.

=head1 ACKNOWLEDGEMENTS

EMS-ESP on github for creating the software.

https://bbqkees-electronics.nl for the hardware and support,

=head1 COPYRIGHT & LICENSE

Copyright 2022 Johan Vromans, all rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut
