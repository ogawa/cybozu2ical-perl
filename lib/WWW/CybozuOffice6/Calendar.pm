# $Id$

package WWW::CybozuOffice6::Calendar;
use strict;
use warnings;

use Encode qw/from_to/;
use LWP::UserAgent;
use DateTime;
use Text::CSV_XS;

our $VERSION = '0.01';

sub new {
    my($class, %param) = @_;
    $param{url} ||= delete $param{cybozu_url};
    $param{ua} ||= LWP::UserAgent->new();
    bless \%param, $class;
}

sub url			{ shift->_accessor('url',		@_) }
sub username		{ shift->_accessor('username',		@_) }
sub userid		{ shift->_accessor('userid',		@_) }
sub password		{ shift->_accessor('password',		@_) }
sub ua			{ shift->_accessor('ua',		@_) }
sub input_encoding	{ shift->_accessor('input_encoding',	@_) }
sub _accessor {
    my $this = shift;
    my $key = shift;
    $this->{$key} = shift if @_;
    $this->{$key};
}

sub get_items {
    my $this = shift;

    my $res = $this->_request();
    die 'Failed to access Cybozu Office 6: ' . $res->status_line
	unless $res->is_success;

    my $content = $res->content;
    from_to($content, $this->{input_encoding} || 'shiftjis', 'utf8');
    my @lines = grep /^\d+,ts\.\d+,/, split(/\r?\n/, $content);

    my @items;
    my $csv = Text::CSV_XS->new({ binary => 1 });
    for my $line (@lines) {
	$csv->parse($line)
	    or die 'Failed to parse CSV input';
	my @fields = $csv->fields;
	next if $#fields < 13; # num. of fields

	my $item = $fields[7] ?
	    $this->_parse_recurrent_event(@fields) :
	    $this->_parse_general_event(@fields);
	push @items, $item if $item;
    }
    wantarray ? @items : $items[0];
}

sub _request {
    my $this = shift;
    $this->{ua}->post($this->{url} . '?page=SyncCalendar', {
	_System    => 'login',
	_Login     => 1,
	csv        => 1,
	notimecard => 1,
	defined $this->{username} ? (_Account => $this->{username}) : (),
	defined $this->{userid}   ? (_Id      => $this->{userid}  ) : (),
	Password   => $this->{password} || '',
    });
}

# handle non-recurrent events
sub _parse_general_event {
    my $this = shift;
    my @fields = @_;

    my $now = DateTime->now;
    my $is_full_day = 0;

    my $start = $this->to_datetime($fields[3], $fields[5]);
    my $end   = $this->to_datetime($fields[4], $fields[6]);
    return unless $start && $end;
    if ($fields[5] eq ':') {		# full-day event
	$start = $start->truncate(to => 'day');
	$end   = $end->add(days => 1)->truncate(to => 'day');
	$is_full_day = 1;
    } elsif ($fields[6] eq ':') {	# event w/o endtime
	$end   = $start->clone->add(minutes => 10);
    }

    my($created) = $fields[1] =~ m/^ts\.(\d+)$/;
    $created = DateTime->from_epoch(epoch => $created || 0);

    my $summary = $fields[11] || '';
    $summary .= ': ' if $summary;
    $summary .= $fields[12] || '';

    my $item = {
	start       => $start,
	end         => $end,
	is_full_day => $is_full_day,
	summary     => $summary,
	description => $fields[13] || $summary,
	created     => $created,
	modified    => $now,
    };
}

# handle recurrent events
sub _parse_recurrent_event {
    my $this = shift;
    my @fields = @_;

    # arrange for _parse_general_event
    my @f = @fields;
    $f[4] = $f[3];
    $f[3] = $f[2];
    my $item = $this->_parse_general_event(@f);

    # frequency
    my %FREQUENCY = ( y => 'YEARLY', m => 'MONTHLY', w => 'WEEKLY',
		      d => 'DAILY', n => 'WEEKDAYS' );
    my $freq = $fields[7];
    if (exists $FREQUENCY{$freq}) {
	$item->{frequency} = $FREQUENCY{$freq};
	$item->{frequency_value} = $fields[8] || 0;
	if ($fields[4] =~ m!^(\d+)/(\d+)/(\d+)$!) {
	    my $until = $item->{end}->clone->set(year => $1, month => $2, day => $3);
	    $until->set_time_zone('UTC');
	    $item->{until} = $until;
	}
    }

    $item;
}

sub to_datetime {
    my $this = shift;
    my($ymd, $hms) = @_;

    my %args;
    return unless $ymd && $ymd =~ m!^(\d+)/(\d+)/(\d+)$!;
    @args{qw(year month day)} = ($1, $2, $3);

    if ($hms && $hms ne ':') {
	return unless $hms =~ m!^(\d+):(\d+)(?:\:?(\d+)?)$!;
	@args{qw(hour minute second)} = ($1, $2, $3 || 0);
	@args{qw(hour minute second)} = (23, 59, 59) if $args{hour} > 23;
    } else {
	@args{qw(hour minute second)} = (0, 0, 0);
    }

    $args{time_zone} = $this->{time_zone} || 'Asia/Tokyo';

    DateTime->new(%args);
}

1;
__END__

=head1 NAME

WWW::CybozuOffice6::Calendar - Perl extension for accessing Cybozu Office 6 Calendar

=head1 SYNOPSIS

  use WWW::CybozuOffice6::Calendar;

  # create a calendar object
  my $calendar = WWW::CybozuOffice6::Calendar->new(
      url => 'http://server/scripts/cbag/ag.exe',
      username => 'username',
      password => 'password'
  );

  # get list of items in the calendar
  my @items = $calendar->get_items();

=head1 DESCRIPTION

C<WWW::CybozuOffice6::Calendar> is a Perl extension for accessing
Cybozu Office 6 Calendar.

=head1 REQUIREMENT

This application requires perl 5.8.0 with following Perl modules
installed on your box.

=over 4

=item Text::CSV_XS

=item DateTime

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

=item ua

(optional) An LWP::UserAgent object used for accessing Cybozu.

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

=item get_items()

Obtains a list of calendar items from Cybozu Office 6. If successful,
an array of new items is returned.  Each item has the following keys:

=over 8

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

=item frequency (string)

Frequency mode of the recurrent item.  Each recurrent items has one
of the following frequency modes:

  "YEARLY", "MONTHLY", "WEEKLY", "DAILY", "WEEKDAYS"

=item frequency_value (integer)

Frequency value of the recurrent item.

=item until (DateTime object)

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

=head1 AUTHOR

Hirotaka Ogawa E<lt>hirotaka.ogawa at gmail.comE<gt>

This script is free software and licensed under the same terms as Perl
(Artistic/GPL).

=cut
