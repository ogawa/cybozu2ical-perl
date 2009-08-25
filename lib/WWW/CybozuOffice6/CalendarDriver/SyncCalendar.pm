# $Id$

package WWW::CybozuOffice6::CalendarDriver::SyncCalendar;
use strict;
use warnings;

use base qw( WWW::CybozuOffice6::CalendarDriver );
use Carp;
use Encode qw( from_to );
use LWP::UserAgent;
use WWW::CybozuOffice6::Calendar::Event;
use WWW::CybozuOffice6::Calendar::RecurrentEvent;

sub request {
    my $driver     = shift;
    my ($cal)      = @_;
    my $date_range = $cal->{date_range} || 30;

    my $ua         = LWP::UserAgent->new;
    my $auth_param = {
        _System => 'login',
        _Login  => 1,
        defined $cal->{username} ? ( _Account => $cal->{username} ) : (),
        defined $cal->{userid}   ? ( _Id      => $cal->{userid} )   : (),
        Password => $cal->{password} || '',
    };

    my $res = $ua->post( $cal->{url} . '?page=SyncCalendar', $auth_param );
    confess 'Failed to access SyncCalendar API: ' . $res->status_line
      unless $res->is_success;
    if ( my $err = $res->header('x-cybozu-error') ) {
        confess 'Failed to access ApiCalendar API: CybozuError = ' . $err;
    }

    my $content = $res->content;
    from_to( $content, $cal->{input_encoding} || 'shiftjis', 'utf8' );
    my @lines = grep /^\d+,ts\.\d+,/, split( /\r\n/, $content );

    carp 'No calendar events found' unless scalar @lines;
    $cal->{response} = \@lines;
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
        next if $num_fields < 13;

        # Cybozu Calendar CSV Format
        #      GENERIC     | RECCURENT
        # [ 0] ID
        # [ 1] TimeStamp
        # [ 2] <BLANK>     x start_date / end_date
        # [ 3] SetDate     x initial start_date?
        # [ 4] EndDate     x until_date
        # [ 5] SetTime
        # [ 6] Endtime
        # [ 7] <BLANK>     | TypeOmit
        # [ 8] <BLANK>     | Day
        # [ 9] Private
        # [10] Banner
        # [11] Event
        # [12] Detail
        # [13] Memo

        my %param;
        @param{
            qw(id timestamp set_time end_time type day private banner event detail memo)
          } = @fields[ 0, 1, 5 .. 13 ];

        $param{set_time} = '' if $param{set_time} eq ':';
        $param{end_time} = '' if $param{end_time} eq ':';

        $param{time_zone} = $cal->{time_zone} || 'Asia/Tokyo';

        if ( $num_fields >= 14 ) {
            my @exception = @fields[ 14 .. $num_fields ];
            $param{exception} = \@exception;
        }

        my $item;
        if ( !$param{type} ) {
            @param{qw(set_date end_date)} = @fields[ 3, 4 ];
            $item = WWW::CybozuOffice6::Calendar::Event->new(%param);
        }
        else {
            @param{qw(set_date end_date until_date)} = @fields[ 2, 2, 4 ];
            $item = WWW::CybozuOffice6::Calendar::RecurrentEvent->new(%param);
        }

        next unless $item;
        $item->comment($line);    # save the CSV line as for debug info.
        push @items, $item;
    }
    wantarray ? @items : $items[0];
}

1;
