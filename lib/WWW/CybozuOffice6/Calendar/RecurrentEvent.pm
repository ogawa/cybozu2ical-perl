# $Id$
package WWW::CybozuOffice6::Calendar::RecurrentEvent;
use strict;
use warnings;

use base qw( WWW::CybozuOffice6::Calendar::Event );
use DateTime;

__PACKAGE__->mk_accessors(qw( rrule frequency frequency_value until ));

sub exdates {
    my ( $this, $value ) = @_;
    return $this->{exdates} = $value if $value;
    return unless $this->{exdates};
    my $exdates = $this->{exdates};
    wantarray ? @$exdates : @$exdates[0];
}

our %FREQUENCY = (
    'y' => 'YEARLY',
    'm' => 'MONTHLY',
    'w' => 'WEEKLY',
    'd' => 'DAILY',

    # weekdays
    'n' => 'WEEKLY',

    # fixed weekday, monthly
    1 => 'MONTHLY',
    2 => 'MONTHLY',
    3 => 'MONTHLY',
    4 => 'MONTHLY',
    5 => 'MONTHLY',
);
our @WEEK_STRING = ( 'SU', 'MO', 'TU', 'WE', 'TH', 'FR', 'SA' );

sub parse {
    my ( $this, %param ) = @_;
    $this->SUPER::parse(%param);

    # rrule
    my ( $type, $day ) = ( $param{type}, $param{day} );
    if ( defined $type && defined $day && exists $FREQUENCY{$type} ) {
        my %rrule = ( FREQ => $FREQUENCY{$type} );
        if ( $type =~ /^[1-5]$/ ) {
            $rrule{BYDAY}    = $type . $WEEK_STRING[$day];
            $rrule{INTERVAL} = 1;
        }
        elsif ( $type eq 'n' ) {
            $rrule{BYDAY} = 'MO,TU,WE,TH,FR';
        }

        # until
        if (
            exists $param{until_date}
            && (   $param{until_date} =~ m!^(\d+)/(\d+)/(\d+)$!
                || $param{until_date} =~ m!^da\.(\d+)\.(\d+)\.(\d+)$! )
          )
        {
            my %args = ( year => $1, month => $2, day => $3 );
            my $until;
            if ( $this->is_full_day ) {
                $until = $this->to_datetime( $param{until_date}, '' );
            }
            else {
                $until = $this->end->clone->set(%args);
                $until->set_time_zone('UTC');    # timezone must be UTC
            }
            $rrule{UNTIL} = $until;
        }

        $this->rrule( \%rrule );

        # for compatibility
        $this->frequency( $rrule{FREQ} );
        $this->frequency_value( $day || 0 );
        $this->until( $rrule{UNTIL} ) if exists $rrule{UNTIL};
    }

    # exdates
    if ( defined $param{exception} ) {
        my @exdates;
        for ( @{ $param{exception} } ) {
            push @exdates, $this->to_datetime( $_, $param{set_time} );
        }
        $this->exdates( \@exdates );
    }

    1;
}

1;
