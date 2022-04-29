# NAME

switchtime - inspect/modify thermostat switch times

# DESCRIPTION

**This program** has three functions.

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
On the command line, speciy **--init** and a series of day codes,
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

# REQUIREMENTS

A suitable thermostat, accessible via an EMS-ESP gateway.

See https://github.com/emsesp/EMS-ESP32 .

# INSTALL

Install the necessary modules:

    $ cpan LWP::UserAgent HTTP::Headers Time::HiRes JSON::PP

Copy the script `switchtime.pl` to any convenient location that is in
your `PATH` and make it executable. For example:

    $ cp switchtime.pl $HOME/bin/switchtime
    $ chmod 0755 $HOME/bin/switchtime

# SUPPORT AND DOCUMENTATION

Development of this module takes place on GitHub:
https://github.com/sciurius/EMS-ESP32-switchtime.

You can find documentation for this module with the perldoc command.

    switchtime --manual

Please report any bugs or feature requests using the issue tracker on
GitHub.

# ACKNOWLEDGEMENTS

EMS-ESP on github for creating the software.

https://bbqkees-electronics.nl for the hardware and support,

# COPYRIGHT & LICENSE

Copyright 2022 Johan Vromans, all rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.
