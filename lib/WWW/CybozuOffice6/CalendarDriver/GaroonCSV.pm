# $Id$

package WWW::CybozuOffice6::CalendarDriver::GaroonCSV;
use strict;
use warnings;

use base qw( WWW::CybozuOffice6::CalendarDriver );
use Carp;
use Encode qw( from_to );
use LWP::UserAgent;
use DateTime;
use WWW::CybozuOffice6::Calendar::Event;
use WWW::CybozuOffice6::Calendar::RecurrentEvent;

#
# find end of line from UTF-8 CSV Data.
#
sub split_line_utf8 {
    use encoding 'utf-8';
    my $text = shift;
    my @lines;

    if (length($text) == 0) {
        return @lines;
    }
    $text = Encode::decode_utf8($text);

    # parser state
    my $newline = 0;
    my $escape = 0;

    # buffer index
    my $ptr = 0;
    my $len = 0;
    while ($ptr < length($text)) {
        my $ch = substr($text, $ptr, 1);
        $ptr += 1;
        $len += 1;

        # escape inside ""
        if ($escape == 1) {
            if ($ch eq "\"") {
                $escape = 0;
            }
            next;
        }
        if ($ch eq "\"") {
            $escape = 1;
            next;
        }

        # handle \r\n
        if ($ch eq "\r") {
            $newline = 1;
            next;
        }
        if ($newline == 1) {
            $newline = 0;
            if ($ch eq "\n") {
                my $line = substr($text, ($ptr - $len), $len - 2);
                if (length($line) == 0) {
                    next;
                }
                $line = Encode::encode_utf8($line);
                push @lines, $line;
                $len = 0;
                next;
            }
            next;
        }
    }

    @lines;
    no encoding;
}

sub request {
    my $driver = shift;
    my ($cal) = @_;
    my $now     = DateTime->today;
    my $ua         = LWP::UserAgent->new;

    my $auth_param = {
        _system  => 1,
        defined $cal->{username} ? ( _account => $cal->{username} ) : (),
        _password => $cal->{password} || '',
    };
    my $range_param = {
        start_year => $now->year,
        start_month => 1,
        start_day => 1,
        end_year => ( $now->year + 1 ),
        end_month => 12,
        end_day => 31,
    };


    # get CSV from server
    my $res = $ua->post(
        $cal->{url} . '/schedule/personal/command_export1/-/schedules.csv?&.csv',
        {
            %$auth_param,
            %$range_param,
            charset => 'UTF-8',
        }
    );

    confess 'Failed to access Garoon CSV Page: ' . $res->status_line
      unless $res->is_success;
    if ( my $err = $res->header('x-cybozu-error') ) {
        confess 'Failed to access Garoon CSV Page: CybozuError = ' . $err;
    }
    my $content = $res->content;

    # description and memo may include \r\n
    my @lines = split_line_utf8($content);
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
        next if $num_fields < 6;

        # Garoon Calendar CSV Format
        # [ 0] SetDate 2010/1/1
        # [ 1] SetTime 12:00:00
        # [ 2] EndDate 2010/12/31
        # [ 3] EndTime 12:00:00
        # [ 4] Location LOCATION-17F
        # [ 5] SUMMARY
        # [ 6] MEMO

        my %param;
        @param{
            qw(set_date set_time end_date end_time location event memo)
        } = @fields[0 ... 6];

        $param{time_zone} = $cal->{time_zone} || 'Asia/Tokyo';

        my $item;
        for my $col (qw(set_date end_date)) {
            $param{$col} = _format_date_string( $param{$col} );
        }
        $item = WWW::CybozuOffice6::Calendar::Event->new(%param);

        next unless $item;
        $item->comment($line);    # save the CSV line as for debug info.
        push @items, $item;
    }
    wantarray ? @items : $items[0];
}

# convert 'da.1970.1.1' to '1970/01/01'
sub _format_date_string {
    my $s = shift;
    if ( $s =~ m!^da\.(\d+)\.(\d+)\.(\d+)$! ) {
        $s = sprintf( '%04d/%02d/%02d', $1, $2, $3 );
    }
    $s;
}

1;
