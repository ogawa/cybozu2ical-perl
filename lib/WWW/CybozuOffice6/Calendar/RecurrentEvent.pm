# $Id$
package WWW::CybozuOffice6::Calendar::RecurrentEvent;
use strict;
use warnings;

use base qw( WWW::CybozuOffice6::Calendar::Event );
use DateTime;

__PACKAGE__->mk_accessors(qw( rrule frequency frequency_value until ));

sub exdates {
    my $this = shift;
    return unless $this->{exdates};
    my $exdates = $this->{exdates};
    wantarray ? @$exdates : @$exdates[0];
}

our %FREQUENCY = (
    y => 'YEARLY',
    m => 'MONTHLY',
    w => 'WEEKLY',
    d => 'DAILY',
    n => 'WEEKDAYS'
);

sub parse {
    my ( $this, %param ) = @_;
    $this->SUPER::parse(%param);

    # frequency
    my $freq = $param{freq};
    return unless $freq && exists $FREQUENCY{$freq};

    # rrule
    my %rrule = ();
    if ( $FREQUENCY{$freq} eq 'WEEKDAYS' ) {
        %rrule = ( FREQ => 'WEEKLY', BYDAY => 'MO,TU,WE,TH,FR' );
    }
    else {
        %rrule = ( FREQ => $FREQUENCY{$freq} );
    }
    if ( $param{freq_value} =~ /^\d(SU|MO|TU|WE|TH|FR|SA)$/ ) {
        $rrule{BYDAY}    = $param{freq_value};
        $rrule{INTERVAL} = 1;
    }

    # until
    if (   $param{until_date} =~ m!^(\d+)/(\d+)/(\d+)$!
        || $param{until_date} =~ m!^da\.(\d+)\.(\d+)\.(\d+)$! )
    {
        my %args = ( year => $1, month => $2, day => $3 );
        my $until;
        if ( $this->{is_full_day} ) {
            $until = $this->to_datetime( $param{until_date}, ':' );
        }
        else {
            $until = $this->{end}->clone->set(%args);
            $until->set_time_zone('UTC');    # timezone must be UTC
        }
        $rrule{UNTIL} = $until;
    }

    $this->{rrule} = \%rrule;

    # exdates
    if ( defined $param{exdates} ) {
        my @exdates;
        for ( @{ $param{exdates} } ) {
            push @exdates, $this->to_datetime( $_, $param{start_time} );
        }
        $this->{exdates} = \@exdates;
    }

    # for compatibility
    $this->{frequency}       = $FREQUENCY{$freq};
    $this->{frequency_value} = $param{freq_value} || 0;
    $this->{until}           = $rrule{UNTIL} if exists $rrule{UNTIL};

    1;
}

1;
