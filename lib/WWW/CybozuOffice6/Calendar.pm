# $Id$

package WWW::CybozuOffice6::Calendar;
use strict;
use warnings;

use base qw( Class::Accessor::Fast );
use Carp;
use Encode qw( from_to );
use LWP::UserAgent;
use WWW::CybozuOffice6::Calendar::Event;
use WWW::CybozuOffice6::Calendar::RecurrentEvent;

our $VERSION = '0.30';

sub new {
    my ( $class, %param ) = @_;
    $param{url} ||= delete $param{cybozu_url};
    bless \%param, $class;
}

__PACKAGE__->mk_accessors(qw( url username userid password input_encoding ));

sub request {
    my $cal = shift;
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

sub read_from_csv_file {
    my $cal = shift;
    my ($file) = @_;
    local *FH;
    open FH, $file or confess "Failed to read $file";
    my @lines;
    while (<FH>) {
        chomp;
        push @lines, $_;
    }
    close(FH);
    $cal->{response} = \@lines;

    scalar @lines ? \@lines : undef;
}

sub response {
    my $res = $_[0]->{response} || {};
    wantarray ? @$res : $res;
}

sub get_items {
    my $cal = shift;

    my $csv;
    if ( eval('require Text::CSV_XS') ) {
        $csv = Text::CSV_XS->new( { binary => 1 } );
    }
    elsif ( eval('require Text::CSV') ) {
        $csv = Text::CSV->new();
    }
    else {
        confess 'Text::CSV_XS or Text::CSV package is required';
    }

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

  # request calendar contents
  $calendar->request();

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

=item request()

Requests to obtain the contents of Cybozu Office 6 Calendar.

=item read_from_csv_file($filename)

Instead of requesting Cybozu Office 6 server, reads from a local CSV file.

=item get_items()

Obtains a list of calendar items from Cybozu Office 6. If successful,
an array of new items is returned.  Each item has the following keys:

=over 8

=item id (string)

A unique id.

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

=item rrule (HASHREF of rrule properties)

Assocative list of recurrence rules for the item, which is *roughly*
based on iCalendar Specification (RFC 2445).

=item exdates (ARRAYREF of DateTime objects)

Excluded dates of the reccurent item.  If the item has no excluded
dates, this should be "undefined".

=item [obsolete] frequency (string)

Frequency mode of the recurrent item.  Each recurrent items has one
of the following frequency modes:

  "YEARLY", "MONTHLY", "WEEKLY", "DAILY", "WEEKDAYS"

=item [obsolete] frequency_value (integer)

Frequency value of the recurrent item.

=item [obsolete] until (DateTime object)

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
