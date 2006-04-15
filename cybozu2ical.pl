#!/usr/bin/perl
# cybozu2ical.pl: converting CybozuOffice6 calendar into iCal format
#
# Hirotaka Ogawa (hirotaka.ogawa at gmail.com)

use strict;
use YAML;
use LWP::UserAgent;
use Encode;
use Text::CSV_XS;
use Data::ICal;
use Data::ICal::Entry::Event;
use Data::ICal::Entry::TimeZone;
use Data::ICal::Entry::TimeZone::Standard;
use Date::ICal;

our $VERSION = '0.01';

my $cfg = YAML::LoadFile($ARGV[0] || 'config.yaml');

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
my $dtstamp = Date::ICal->new(epoch => time)->ical;

while ($#lines != -1) {
    my $line = shift(@lines);
    $csv->parse($line)
	or die 'failed to parse CSV input.';
    my @fields = $csv->fields;
    next if $#fields < 13; # num. of fields

    my $epoch = $fields[1];
    $epoch =~ s/ts\.//;
    my $created = Date::ICal->new(epoch => $epoch)->ical;

    my @d = split("/", $fields[3]);
    my @t = split(":", $fields[5]);
    my $date = Date::ICal->new(
	year => $d[0], month => $d[1], day => $d[2],
	hour => $t[0] || 0, min => $t[1] || 0, sec => $t[2] || 0
    );
    my $dtstart = $date->ical(offset => '+0900');
    $dtstart =~ s/T000000// if $fields[5] =~ /^:$/;

    my @d = split("/", $fields[4]);
    my @t = split(":", $fields[6]);
    my $date = Date::ICal->new(
	year => $d[0], month => $d[1], day => $d[2],
	hour => $t[0] || 0, min => $t[1] || 0, sec => $t[2] || 0
    );
    $date += 'P1D' if $fields[6] =~ /^:$/; # full-day or multiple-days events
    my $dtend = $date->ical(offset => '+0900');
    $dtend =~ s/T000000// if $fields[6] =~ /^:$/;

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
$vtimezone->add_properties(tzid => 'Asia/Tokyo');

my $standard = Data::ICal::Entry::TimeZone::Standard->new();
$standard->add_properties(
    tzoffsetfrom => '+0900',
    tzoffsetto => '+0900',
    tzname => 'JST',
    dtstart => '19700101T000000'
);

$vtimezone->add_entry($standard);
$vcalendar->add_entry($vtimezone);

print $vcalendar->as_string;

1;
