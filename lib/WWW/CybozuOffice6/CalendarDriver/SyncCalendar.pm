# $Id$

package WWW::CybozuOffice6::CalendarDriver::SyncCalendar;
use strict;
use warnings;

use Carp;
use Encode qw( from_to );
use LWP::UserAgent;
use DateTime;
use WWW::CybozuOffice6::Calendar::Event;
use WWW::CybozuOffice6::Calendar::RecurrentEvent;

sub request {
    my $class      = shift;
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

    my $content = $res->content;
    from_to( $content, $cal->{input_encoding} || 'shiftjis', 'utf8' );
    my @lines = grep /^\d+,ts\.\d+,/, split( /\r?\n/, $content );
    $cal->{response} = \@lines;

    scalar @lines ? \@lines : undef;
}

sub get_items {
    my $class = shift;
    my ($cal) = @_;

    my $csv;
    if ( eval('require Text::CSV_XS') ) {
        $csv = Text::CSV_XS->new( { binary => 1 } );
    }
    elsif ( eval('require Text::CSV') ) {
        $csv = Text::CSV->new;
    }
    confess 'Text::CSV_XS or Text::CSV package is required' unless $csv;

    my @items;
    for my $line ( $cal->response ) {
        $csv->parse($line)
          or confess 'Failed to parse CSV input';
        my @fields     = $csv->fields;
        my $num_fields = @fields - 1;
        next if $num_fields < 13;
        $fields[1] =~ s/^ts\.//;    # remove rubbish

        # Cybozu Calendar CSV Format
        #      GENERIC     | RECCURENT
        # [ 0] id?         | id?
        # [ 1] created     | created
        # [ 2] <BLANK>     x start_date / end_date
        # [ 3] start_date  x initial start_date?
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
        @param{
            qw(id created start_time end_time freq freq_value abbrev summary description)
          } = @fields[ 0, 1, 5 .. 8, 11 .. 13 ];
        $param{time_zone} = $cal->{time_zone} || 'Asia/Tokyo';

        my $item;
        if ( !$param{freq} ) {
            @param{qw(start_date end_date)} = @fields[ 3, 4 ];
            $item = WWW::CybozuOffice6::Calendar::Event->new(%param);
        }
        else {
            @param{qw(start_date end_date until_date)} = @fields[ 2, 2, 4 ];
            if ( $num_fields > 13 ) {
                my @exdates = @fields[ 14 .. $num_fields ];
                $param{exdates} = \@exdates;
            }
            my $freq = $param{freq};
            if ( $freq =~ /^[1-5]$/ ) {
                $param{freq} = 'm';
                my @week_str = ( 'SU', 'MO', 'TU', 'WE', 'TH', 'FR', 'SA' );
                $param{freq_value} = $freq . $week_str[ $param{freq_value} ];
            }
            $item = WWW::CybozuOffice6::Calendar::RecurrentEvent->new(%param);
        }

        next unless $item;
        $item->comment($line);    # save the CSV line as for debug info.
        push @items, $item;
    }
    wantarray ? @items : $items[0];
}

1;
