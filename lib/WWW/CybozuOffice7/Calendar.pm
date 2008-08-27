# $Id$

package WWW::CybozuOffice7::Calendar;
use strict;
use warnings;

use base qw( WWW::CybozuOffice6::Calendar );

use Carp;
use Encode qw( from_to );
use LWP::UserAgent;
use URI;
use DateTime;

our $VERSION = '0.20';

sub request {
    my $this = shift;
    my $date_range = $this->{date_range} || 30;

    my $now = DateTime->now;
    my $setdate = $now->clone->subtract(days => $date_range)->strftime('da.%Y.%m.%d');
    my $enddate = $now->clone->add(days => $date_range)->strftime('da.%Y.%m.%d');

    my $params = {
	_System  => 'login',
	_Login   => 1,
	defined $this->{username} ? (_Account => $this->{username}) : (),
	defined $this->{userid}   ? (_Id      => $this->{userid}  ) : (),
	Password => $this->{password} || '',
    };
    
    # First, get a list of EID
    my $res = $this->{ua}->post($this->{url} . '?page=ApiCalendar', {
	%$params,
	SetDate => $setdate,
	EndDate => $enddate,
    });
    confess 'Failed to access Cybozu Office 7: ' . $res->status_line
	unless $res->is_success;

    my @lines;
    for my $line (split(/\r?\n/, $res->content)) {
	next unless $line =~ /^ts\.\d+,(\d+),(da\..+$)/;

	# Second, get a complete event from EID
	my $res = $this->{ua}->post($this->{url} . '?page=ApiCalendar', {
	    %$params,
	    EID  => $1,
	    Date => $2,
	});
	unless ($res->is_success) {
	    carp 'Failed to access Cybozu Office 7: ' . $res->status_line;
	    next;
	}

	my $content = $res->content;
	from_to($content, $this->{input_encoding} || 'shiftjis', 'utf8');
	my $line = (split(/\r?\n/, $content))[0];
	$line .= '"' if $line !~ /\"$/; # Cybozu bug: may produce broken CSV lines
	push @lines, $line;
    }

    $this->{response} = \@lines;
    scalar @lines ? \@lines : undef;
}

sub get_items {
    my $this = shift;

    my $csv;
    if (eval('require Text::CSV_XS')) {
	$csv = Text::CSV_XS->new({ binary => 1 });
    } elsif (eval('require Text::CSV')) {
	$csv = Text::CSV->new();
    } else {
	confess 'Text::CSV_XS or Text::CSV package is required';
    }

    my @items;
    for my $line ($this->response) {
	$csv->parse($line)
	    or confess 'Failed to parse CSV input';
	my @fields = $csv->fields;
	my $num_fields = @fields - 1;
	next if $num_fields < 14;
	$fields[1] =~ s/^ts\.//; # remove rubbish

	# Cybozu Calendar CSV Format
	# [ 0] $Item.ID
	# [ 1] $TimeStamp
	# [ 2] $s
	# [ 3] $Date
	# [ 4] $Item.TypeOmit
	# [ 5] $Item.Day
	# [ 6] $Item.Private
	# [ 7] $Item.Banner
	# [ 8] $Item.SetDate || $Item.SetTime.Date
	# [ 9] $Item.EndDate || $Item.EndTime.Date
	# [10] $Item.SetTime.Hour00:$Item.SetTime.Minute00
	# [11] $Item.EndTime.Hour00:$Item.EndTime.Minute00
	# [12] $Item.Event
	# [13] $Item.Detail
	# [14] $Item.Memo

	my %param;
	@param{qw(id created freq freq_value start_date end_date start_time end_time abbrev summary description)} = @fields[0,1,4,5,8..11,12..14];

	$param{time_zone} = $this->{time_zone} || 'Asia/Tokyo';

	my $item;
	if (!$param{freq}) {
	    $item = WWW::CybozuOffice6::Calendar::Event->new(%param);
	}
	else {
	    @param{qw(end_date until_date)} = @fields[8,9];
	    if ($num_fields > 14) {
		my @exdates = @fields[14..$num_fields];
		$param{exdates} = \@exdates;
	    }
	    my $freq = $param{freq};
	    if ($freq =~ /^[1-5]$/) {
		$param{freq} = 'm';
		my @week_str = ('SU', 'MO', 'TU', 'WE', 'TH', 'FR', 'SA');
		$param{freq_value} = $freq . $week_str[$param{freq_value}];
	    }
	    $item = WWW::CybozuOffice6::Calendar::RecurrentEvent->new(%param);
	}

	next unless $item;
	$item->comment($line); # save the CSV line as for debug info.
	push @items, $item;
    }
    wantarray ? @items : $items[0];
}

1;
__END__

=head1 NAME

WWW::CybozuOffice7::Calendar - Perl extension for accessing Cybozu Office 7 Calendar

=head1 SYNOPSIS

  use WWW::CybozuOffice7::Calendar;

  # create a calendar object
  my $calendar = WWW::CybozuOffice7::Calendar->new(
      url => 'http://server/scripts/cbag/ag.exe',
      username => 'username',
      password => 'password'
  );

  # request calendar contents
  $calendar->request();

  # get list of items in the calendar
  my @items = $calendar->get_items();

=head1 DESCRIPTION

C<WWW::CybozuOffice7::Calendar> is a Perl extension for accessing
Cybozu Office 7 Calendar.

For more detail, please consult POD of C<WWW::CybozuOffice6::Calendar>.

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
