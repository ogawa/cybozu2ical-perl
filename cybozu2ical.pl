#!/usr/bin/perl
# cybozu2ical.pl: converting CybozuOffice6 calendar into iCal format
#
# Hirotaka Ogawa (hirotaka.ogawa at gmail.com)

use strict;
use vars qw($URL $USER $PASS);

$URL = 'http://www.example.com/cbag/ag.cgi';
$USER = 'user';
$PASS = 'pass';

use LWP::UserAgent;
use Encode;
use Text::CSV_XS;
use Data::ICal;
use Data::ICal::Entry::Event;
use Date::ICal;

my $ua = LWP::UserAgent->new();

my $res = $ua->post($URL . '?page=SyncCalendar', {
    _System => 'login',
    _Login => '1',
    _Account => $USER,
    Password => $PASS,
    'csv' => 1,
    'notimecard' => 1,
});

die "Cannot access Cyboze Office 6 ($URL)." unless $res->is_success;

my $content = $res->content;
Encode::from_to($content, 'shiftjis', 'utf8');

my @lines = grep /^\d+,ts\.\d+,/, split(/\r?\n/, $content);
my $csv = Text::CSV_XS->new({ binary => 1 });

my $calendar = Data::ICal->new();

while ($#lines != -1) {
    my $line = shift(@lines);
    $csv->parse($line)
	or die 'failed to parse CSV input.';
    my @fields = $csv->fields;
    next if $#fields != 13; # num. of fields

    my @d = split("/", $fields[3]);
    my %param = ( year => $d[0], month => $d[1], day => $d[2] ); 
    if ($fields[5] !~ /^:$/) {
	my @t = split(":", $fields[5]);
	$param{hour} = $t[0];
	$param{min} = $t[1];
	$param{sec} = $t[2] || 0;
    }
    my $dtstart = Date::ICal->new(%param);

    my @d = split("/", $fields[4]);
    my %param = ( year => $d[0], month => $d[1], day => $d[2] ); 
    if ($fields[6] !~ /^:$/) {
	my @t = split(":", $fields[6]);
	$param{hour} = $t[0];
	$param{min} = $t[1];
	$param{sec} = $t[2] || 0;
    }
    my $dtend = Date::ICal->new(%param);

    my $event = Data::ICal::Entry::Event->new();
    $event->add_properties(
			   summary => $fields[12] || '',
			   description => $fields[13] || $fields[12] || '',
			   dtstart => $dtstart->ical,
			   dtend => $dtend->ical,
			   );
    $calendar->add_entry($event);
}

print $calendar->as_string;

1;
