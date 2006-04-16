#!/usr/bin/perl
# cybozu2ical: Convert Cybozu Office 6 calendar into iCal format
#
# $Id$

use strict;
use YAML;
use LWP::UserAgent;
use Encode;
use Text::CSV_XS;
use Data::ICal;
use Data::ICal::Entry::Event;
use Data::ICal::Entry::TimeZone;
use Data::ICal::Entry::TimeZone::Standard;
use DateTime;
use DateTime::TimeZone;

our $VERSION = '0.02';

my $cfg = YAML::LoadFile($ARGV[0] || 'config.yaml');
my $tz = DateTime::TimeZone->new(name => $cfg->{time_zone} || 'Asia/Tokyo');

my $ua = LWP::UserAgent->new();

my $res = $ua->post($cfg->{cybozu_url} . '?page=SyncCalendar', {
    _System => 'login',
    _Login => '1',
    _Account => $cfg->{username},
    Password => $cfg->{password},
    'csv' => 1,
    'notimecard' => 1,
});

die "Cannot access Cybozu Office 6 (" . $cfg->{cybozu_url} . ")."
    unless $res->is_success;

my $content = $res->content;
Encode::from_to($content, 'shiftjis', 'utf8');

my @lines = grep /^\d+,ts\.\d+,/, split(/\r?\n/, $content);
my $csv = Text::CSV_XS->new({ binary => 1 });

my $vcalendar = Data::ICal->new();
$vcalendar->add_properties(
    prodid => 'Cybozu2ICal',
    version => $VERSION,
    calscale => 'GREGORIAN',
    method => 'PUBLISH'
);

# current timestamp
my $dtstamp = dt2ical(DateTime->from_epoch(epoch => time));

while ($#lines != -1) {
    my $line = shift(@lines);
    $csv->parse($line)
	or die 'failed to parse CSV input.';
    my @fields = $csv->fields;
    next if $#fields < 13; # num. of fields

    my $epoch = $fields[1];
    $epoch =~ s/ts\.//;
    my $created = dt2ical(DateTime->from_epoch(epoch => $epoch));

    my $dt1 = cydate2dt($fields[3], $fields[5], $tz);
    my $dtstart = ($fields[5] !~ /^:$/) ?
	dt2ical($dt1) : $dt1->ymd('');

    my $dt2 = cydate2dt($fields[4], $fields[6], $tz);
    my $dtend = ($fields[6] !~ /^:$/) ?
	dt2ical($dt2) : $dt2->add(days => 1)->ymd('');

    my $vevent = Data::ICal::Entry::Event->new();
    $vevent->add_properties(
	summary => $fields[12] || '',
	description => $fields[13] || $fields[12] || '',
	dtstart => $dtstart,
	dtend => $dtend,
	dtstamp => $dtstamp,
	created => $created
    );

    $vcalendar->add_entry($vevent);
}

my $vtimezone = Data::ICal::Entry::TimeZone->new();
$vtimezone->add_properties(tzid => $tz->name);

# probably we need to support the Daylight Saving Time
my $standard = Data::ICal::Entry::TimeZone::Standard->new();

my $dt = cydate2dt("1970/01/01", "00:00:00", $tz);
my $offset = DateTime::TimeZone::offset_as_string($dt->offset) || '+0900';
my $tzname = $cfg->{tzname} || $tz->short_name_for_datetime($dt) || 'JST';

$standard->add_properties(
    tzoffsetfrom => $offset,
    tzoffsetto => $offset,
    tzname => $tzname,
    dtstart => dt2ical($dt)
);
$vtimezone->add_entry($standard);

$vcalendar->add_entry($vtimezone);

print $vcalendar->as_string;

sub cydate2dt {
    my($date, $time, $tz) = @_;
    my @d = split("/", $date);
    my @t = split(":", $time);

    my $dt = DateTime->new(
	year => $d[0], month => $d[1], day => $d[2],
	hour => $t[0] || 0, minute => $t[1] || 0, second => $t[2] || 0,
	time_zone => $tz || 'Asia/Tokyo'
    );
    return $dt;
}

sub dt2ical {
    my($dt) = @_;
    $dt->ymd('') . 'T' . $dt->hms('') . ($dt->time_zone->is_utc ? 'Z' : '');
}

1;
=head1 NAME

cybozu2ical - Convert CybozuOffice6 calendar into iCal format

=head1 SYNOPSIS

  % cybozu2ical
  % cybozu2ical /path/to/config.yaml

=head1 DESCRIPTION

=head1 DESCRIPTION

C<cybozu2ical> is a command line application that fetches Cybozu
Office 6 calendar items and converts them into a iCal file.  It allows
you to easily integrate the Cybozu Calendar into iCalendar-enabled
Calendar applications, such as Microsoft Outlook, Apple iCal, and of
course, Google Calendar.

You can run this via crontab, for example, every 1 hour.

=head1 REQUIREMENT

This application requires perl 5.8.0 with following Perl modules
installed on your box.

=over 4

=item Data::ICal

=item DateTime

=item YAML

=back

=head1 OPTIONS

This application has a command-line option as follows:

=over 4

=item path/to/config.yaml

Specified the path to a configuration file. By default, C<config.yaml>
in the current directory.

=back

=head1 CONFIGURATION

The distributions includes a sample configuration file
C<config.yaml.sample>. You can rename it to C<config.yaml> and
configure C<cybozu2ical>.

=over 4

=item cybozu_url

Set the URL of your Cybozu Office 6.

=item username, password

Set your username and password for Cybozu Office 6.

=item time_zone

Set the timezone of your Cybozu Office 6 (e.g., Asia/Tokyo).

=item tzname

Set the short timezone name of your Cybozu Office 6 (e.g., JST).

=back

=head1 DEVELOPMENT

The development version is always available from the following
subversion repository:

  svn://svn.as-is.net/public/cybozu2ical/trunk

You can browse the files via SVN::Web from the following:

  http://svn.as-is.net/svnweb/public/browse/cybozu2ical/trunk/

Any comments, suggestions, or patches are welcome.

=head1 AUTHOR

Hirotaka Ogawa E<lt>hirotaka.ogawa at gmail.comE<gt>

This script is free software and licensed under the same terms as Perl
(Artistic/GPL).

=cut
