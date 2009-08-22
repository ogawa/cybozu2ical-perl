# $Id$

package WWW::CybozuOffice6::Calendar;
use strict;
use warnings;

use base qw( Class::Accessor::Fast );
use Carp;
use Encode qw( from_to );
use LWP::UserAgent;
use WWW::CybozuOffice6::Calendar::Event;
use WWW::CybozuOffice6::Calendar::RecurrentEvent;

our $VERSION = '0.35';

sub new {
    my $class   = shift;
    my (%param) = @_;
    my $cal     = bless \%param, $class;
    $cal->{url} ||= delete $cal->{cybozu_url};
    $cal->{calendar_driver} =
      WWW::CybozuOffice6::CalendarDriverFactory->get_driver(
        $cal->{calendar_driver} )
      unless ref $cal->{calendar_driver};
    $cal;
}

__PACKAGE__->mk_accessors(qw( url username userid password input_encoding ));

sub request {
    my $cal = shift;
    $cal->{calendar_driver}->request($cal);
}

sub read_from_csv_file {
    my $cal = shift;
    my ($file) = @_;
    local $/ = "\r\n";
    local *FH;
    open FH, $file or confess "Failed to read $file";
    my @lines;
    while (<FH>) {
        chomp;
        push @lines, $_;
    }
    close(FH);
    $cal->{response} = \@lines;

    scalar @lines ? \@lines : undef;
}

sub response {
    my $res = $_[0]->{response} || {};
    wantarray ? @$res : $res;
}

sub get_items {
    my $cal = shift;
    $cal->{calendar_driver}->get_items($cal);
}

package WWW::CybozuOffice6::CalendarDriverFactory;

sub get_driver {
    my $class = shift;
    my ($driver_name) = @_;
    $driver_name ||= 'ApiCalendar';
    $driver_name = 'WWW::CybozuOffice6::CalendarDriver::' . $driver_name
      if $driver_name !~ m/^WWW::CybozuOffice6::CalendarDriver::/;
    eval "use $driver_name;";
    $driver_name->new;
}

1;
__END__

=head1 NAME

WWW::CybozuOffice6::Calendar - Perl extension for accessing Cybozu Office Calendar

=head1 SYNOPSIS

  use WWW::CybozuOffice6::Calendar;

  # create a calendar object
  my $calendar = WWW::CybozuOffice6::Calendar->new(
      url => 'http://server/scripts/cbag/ag.exe',
      username => 'username',
      password => 'password'
  );

  # request calendar contents
  $calendar->request();

  # get list of items in the calendar
  my @items = $calendar->get_items();

=head1 DESCRIPTION

C<WWW::CybozuOffice6::Calendar> is a Perl extension for accessing
Cybozu Office Calendar.

=head1 REQUIREMENT

This application requires perl 5.8.0 with following Perl modules
installed on your box.

=over 4

=item Text::CSV 1.0+

=item DateTime

=item LWP::UserAgent

=item Class::Accessor::Fast

=back

=head1 FUNCTIONS

=over 4

=item new(%attr)

Creates and returns a new instance of WWW::CybozuOffice6.  Following
attributes are available.

=over 8

=item url

URL of your Cybozu Office 6 server.

=item username, userid

Username or UserID for Cybozu Office 6.

=item password

Password for Cybozu Office 6.

=item input_encoding

Input encoding of Cybozu Office 6. Default is shift_jis.

=back

=item url([$new_url])

Gets/sets the Cybozu Office 6 URL.

=item username([$new_username])

Gets/sets the Cybozu Office 6 username.

=item userid([$new_userid])

Gets/sets the Cybozu Office 6 userid.

=item password([$new_password])

Gets/sets the Cybozu Office 6 password.

=item ua([$new_ua])

Gets/sets the LWP::UserAgent object used to access Cybozu Office 6.

=item input_encoding([$new_input_encoding])

Gets/sets the Cybozu Office 6 encoding.

=item request()

Requests to obtain the contents of Cybozu Office 6 Calendar.

=item read_from_csv_file($filename)

Instead of requesting Cybozu Office 6 server, reads from a local CSV file.

=item get_items()

Obtains a list of calendar items from Cybozu Office 6. If successful,
an array of new items is returned.  Each item has the following keys:

=over 8

=item id (string)

A unique id.

=item start (DateTime object)

Start date of the item.

=item end (DateTime object)

End date of the item.

=item is_full_day (0/1)

Returns 1 for full-day calendar item. Otherwise, returns 0.

=item summary (string)

Summary of the item.

=item description (string)

Description of the item.

=item created (DateTime object)

Created date of the item.  DateTime object.

=item modified (DateTime object)

Modified date of the item, or current timestamp.  DateTime object.

=item rrule (HASHREF of rrule properties)

Assocative list of recurrence rules for the item, which is *roughly*
based on iCalendar Specification (RFC 2445).

=item exdates (ARRAYREF of DateTime objects)

Excluded dates of the reccurent item.  If the item has no excluded
dates, this should be "undefined".

=item [obsolete] frequency (string)

Frequency mode of the recurrent item.  Each recurrent items has one
of the following frequency modes:

  "YEARLY", "MONTHLY", "WEEKLY", "DAILY", "WEEKDAYS"

=item [obsolete] frequency_value (integer)

Frequency value of the recurrent item.

=item [obsolete] until (DateTime object)

End date of the recurrence for the recurrent item.  If the recurrence
continues infinitely, thie value should be "undefined".

=back

=back

=head1 EXPORT

None.

=head1 DEVELOPMENT

The development version is always available from the following
subversion repository:

  http://code.as-is.net/svn/public/WWW-CybozuOffice6-Calendar/trunk/

You can browse the files via Trac from the following:

  http://code.as-is.net/public/browser/WWW-CybozuOffice6-Calendar/trunk/

Any comments, suggestions, or patches are welcome.

=head1 LICENSE

Copyright (c) 2008 Hirotaka Ogawa E<lt>hirotaka.ogawa at gmail.comE<gt>.
All rights reserved.

This library is free software; you can redistribute it and/or modify
it under the terms of either:
       
   a) the GNU General Public License as published by the Free Software
      Foundation; either version 1, or (at your option) any later
      version, or
                         
   b) the "Artistic License" which comes with Perl.

=cut
