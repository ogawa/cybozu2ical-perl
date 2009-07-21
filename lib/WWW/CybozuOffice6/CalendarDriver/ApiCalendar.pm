# $Id$

package WWW::CybozuOffice6::CalendarDriver::ApiCalendar;
use strict;
use warnings;

use base qw( WWW::CybozuOffice6::CalendarDriver );
use Carp;
use Encode qw( from_to );
use LWP::UserAgent;
use DateTime;
use WWW::CybozuOffice6::Calendar::Event;
use WWW::CybozuOffice6::Calendar::RecurrentEvent;

sub request {
    my $driver = shift;
    my ($cal) = @_;

    my $now     = DateTime->today;
    my $setdate = 'da.' . $now->year . '.01.01';
    my $enddate = 'da.' . ( $now->year + 10 ) . '.12.31';
    if ( my $date_range = $cal->{date_range} ) {
        $setdate =
          $now->clone->subtract( days => $date_range )->strftime('da.%Y.%m.%d');
    }

    my $ua         = LWP::UserAgent->new;
    my $auth_param = {
        _System => 'login',
        _Login  => 1,
        defined $cal->{username} ? ( _Account => $cal->{username} ) : (),
        defined $cal->{userid}   ? ( _Id      => $cal->{userid} )   : (),
        Password => $cal->{password} || '',
    };

    # First, get a list of EID
    my $res = $ua->post(
        $cal->{url} . '?page=ApiCalendar',
        {
            %$auth_param,
            SetDate => $setdate,
            EndDate => $enddate,
        }
    );
    confess 'Failed to access ApiCalendar API: ' . $res->status_line
      unless $res->is_success;
    if ( my $err = $res->header('x-cybozu-error') ) {
        confess 'Failed to access ApiCalendar API: CybozuError = ' . $err;
    }

    my @lines;
    for my $line ( split( /\r?\n/, $res->content ) ) {
        next unless $line =~ /^ts\.\d+,(\d+),(da\..+$)/;

        # Second, get a complete event from EID
        my $res = $ua->post(
            $cal->{url} . '?page=ApiCalendar',
            {
                %$auth_param,
                EID  => $1,
                Date => $2,
            }
        );
        unless ( $res->is_success ) {
            carp 'Failed to access Cybozu Office 7: ' . $res->status_line;
            next;
        }

        my $content = $res->content;
        $content =~ s/\r?\n[^\r\n]*$//;    # remove last line
        from_to( $content, $cal->{input_encoding} || 'shiftjis', 'utf8' );

        push @lines, $content;
    }

    $cal->{response} = \@lines;
    scalar @lines ? \@lines : undef;
}

sub get_items {
    my $driver = shift;
    my ($cal) = @_;

    my @items;
    my $csv = $driver->{csv};
    for my $line ( $cal->response ) {
        $csv->parse($line)
          or confess 'Failed to parse CSV input';
        my @fields     = $csv->fields;
        my $num_fields = @fields - 1;
        next if $num_fields < 14;

        # Cybozu Calendar CSV Format
        # [ 0] $Item.ID
        # [ 1] $TimeStamp
        # [ 2] $s (Shared)
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
        @param{
            qw(id timestamp shared type day private banner set_date end_date set_time end_time event detail memo)
          } = @fields[ 0 .. 2, 4 .. 14 ];

        $param{time_zone} = $cal->{time_zone} || 'Asia/Tokyo';

        if ( $num_fields >= 14 ) {
            my @exception = @fields[ 14 .. $num_fields ];
            $param{exception} = \@exception;
        }

        my $item;
        if ( !$param{type} ) {
            $item = WWW::CybozuOffice6::Calendar::Event->new(%param);
        }
        else {
            @param{qw(end_date until_date)} = @fields[ 8, 9 ];
            $item = WWW::CybozuOffice6::Calendar::RecurrentEvent->new(%param);
        }

        next unless $item;
        $item->comment($line);    # save the CSV line as for debug info.
        push @items, $item;
    }
    wantarray ? @items : $items[0];
}

1;
