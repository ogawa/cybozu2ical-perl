# $Id$

package WWW::CybozuOffice6::Calendar;
use strict;
use warnings;

use Encode qw/from_to/;
use LWP::UserAgent;
use DateTime;
use Text::CSV_XS;

our $VERSION = '0.02';

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
	$fields[1] =~ s/^ts\.//; # remove rubbish

	# Cybozu Calendar CSV Format
	#      GENERIC     | RECCURENT
	# [ 0] id?         | id?
	# [ 1] created     | created
	# [ 2] <BLANK>     x start_date
	# [ 3] start_date  x end_date
	# [ 4] end_date    x until_date
	# [ 5] start_time  | start_time
	# [ 6] end_time    | end_time
	# [ 7] <BLANK>     | freq
	# [ 8] <BLANK>     | freq_value
	# [ 9] ???         | ???
	# [10] ???         | ???
	# [11] abbrev      | abbrev
	# [12] summary     | summary
	# [13] description | description

	my %param;
	@param{qw(id created start_time end_time freq freq_value abbrev summary description)} = @fields[0,1,5..8,11..13];
	$param{time_zone} = $this->{time_zone} || 'Asia/Tokyo';

	my $item;
	if (!$param{freq}) {
	    @param{qw(start_date end_date)} = @fields[3,4];
	    $item = WWW::CybozuOffice6::Calendar::Event->new(%param);
	} else {
	    @param{qw(start_date end_date until_date)} = @fields[2..4];
	    $item = WWW::CybozuOffice6::Calendar::RecurentEvent->new(%param);
	}

	next unless $item;
	$item->comment($line); # save the CSV line as for debug info.
	push @items, $item;
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

package WWW::CybozuOffice6::Calendar::Event;

sub new {
    my $class = shift;
    my $self = {
	is_full_day => 0,
	modified => DateTime->now,
    };
    bless $self, $class;
    return unless $self->parse(@_);
    $self;
}

sub id		{ shift->_accessor('id',		@_) }
sub start	{ shift->_accessor('start',		@_) }
sub end		{ shift->_accessor('end',		@_) }
sub summary	{ shift->_accessor('summary',		@_) }
sub description	{ shift->_accessor('description',	@_) }
sub created	{ shift->_accessor('created',		@_) }
sub modified	{ shift->_accessor('modified',		@_) }
sub is_full_day	{ shift->_accessor('is_full_day',	@_) }
sub comment	{ shift->_accessor('comment',		@_) }
sub _accessor {
    my $this = shift;
    my $key = shift;
    $this->{$key} = shift if @_;
    $this->{$key};
}

sub parse {
    my($this, %param) = @_;

    $this->{id} = $param{id} || '0';
    $this->{time_zone} = $param{time_zone} || 'Asia/Tokyo';

    my $start = $this->to_datetime($param{start_date}, $param{start_time});
    my $end   = $this->to_datetime($param{end_date},   $param{end_time});
    return unless $start && $end;

    # (start_time == empty) => A full-day event
    # (start_time != empty) && (end_time == empty) => A malformed event
    if ($param{start_time} eq ':') {
	$start = $start->truncate(to => 'day');
	$end   = $end->add(days => 1)->truncate(to => 'day');
	$this->{is_full_day} = 1;
    } elsif ($param{end_time} eq ':') {
	$end   = $start->clone->add(minutes => 10);
    }
    $this->{start} = $start;
    $this->{end}   = $end;

    $this->{created} = DateTime->from_epoch(epoch => $param{created} || 0);

    my $summary = ($param{abbrev} ? $param{abbrev} . ': ' : '') . $param{summary};
    $this->{summary} = $summary;
    $this->{description} = $param{description} || $summary;
    1;
}

# convert (ymd, hms) pair to a DateTime object (timezone: localtime)
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

    $args{time_zone} = $this->{time_zone};

    DateTime->new(%args);
}

package WWW::CybozuOffice6::Calendar::RecurrentEvent;

@WWW::CybozuOffice6::Calendar::RecurrentEvent::ISA = qw( WWW::CybozuOffice6::Calendar::Event );

sub frequency		{ shift->_accessor('frequency',		@_) }
sub frequency_value	{ shift->_accessor('frequency_value',	@_) }

our %FREQUENCY = ( y => 'YEARLY', m => 'MONTHLY', w => 'WEEKLY',
		   d => 'DAILY', n => 'WEEKDAYS' );
sub parse {
    my($this, %param) = @_;
    $this->SUPER::parse(%param);

    # frequency
    my $freq = $param{freq};
    return unless $freq && exists $FREQUENCY{$freq};

    $this->{frequency} = $FREQUENCY{$freq};
    $this->{frequency_value} = $param{freq_value} || 0;

    if ($param{until_date} =~ m!^(\d+)/(\d+)/(\d+)$!) {
	my %args = (year => $1, month => $2, day => $3);
	my $until;
	if ($this->{is_full_day}) {
	    $until = $this->to_datetime($param{until_date}, ':');
	} else {
	    $until = $this->{end}->clone->set(%args);
	    $until->set_time_zone('UTC'); # timezone must be UTC
	}
	$this->{until} = $until;
    }
    1;
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
