# $Id$
package WWW::CybozuOffice6::Calendar::Event;
use strict;
use warnings;

use base qw( Class::Accessor::Fast );
use DateTime;

sub new {
    my $class = shift;
    my $self  = {
        is_full_day => 0,
        modified    => DateTime->now,
    };
    bless $self, $class;
    return unless $self->parse(@_);
    $self;
}

__PACKAGE__->mk_accessors(
    qw( id start end summary description created time_zone modified is_full_day comment )
);

sub parse {
    my ( $this, %param ) = @_;

    $this->id( $param{id}               || '0' );
    $this->time_zone( $param{time_zone} || 'Asia/Tokyo' );

    my $start = $this->to_datetime( $param{set_date}, $param{set_time} );
    my $end   = $this->to_datetime( $param{end_date}, $param{end_time} );
    return unless $start && $end;

    # (set_time == empty) => A full-day event
    # (set_time != empty) && (end_time == empty) => A malformed event
    if ( $param{set_time} eq '' || $param{set_time} eq ':' ) {
        $start = $start->truncate( to => 'day' );
        $end = $end->add( days => 1 )->truncate( to => 'day' );
        $this->is_full_day(1);
    }
    elsif ( $param{end_time} eq '' || $param{end_time} eq ':' ) {
        $end = $start->clone->add( minutes => 10 );
    }
    $this->start($start);
    $this->end($end);

    $param{timestamp} =~ s/^ts\.//;    # remove rubbish
    $this->created( DateTime->from_epoch( epoch => $param{timestamp} || 0 ) );

    my $summary =
      ( $param{event} ? $param{event} . ': ' : '' ) . $param{detail};
    $this->summary($summary);
    $this->description( $param{memo} || $summary );
    1;
}

# convert (ymd, hms) pair to a DateTime object (timezone: localtime)
sub to_datetime {
    my $this = shift;
    my ( $ymd, $hms ) = @_;

    my %args;
    return
      unless $ymd
          && ( $ymd =~ m!^da\.(\d+)\.(\d+)\.(\d+)$!
              ||    $ymd =~ m!^(\d+)/(\d+)/(\d+)$! );
    @args{qw(year month day)} = ( $1, $2, $3 );

    if ( $hms && $hms ne ':' ) {
        return unless $hms =~ m!^(\d+):(\d+)(?:\:?(\d+)?)$!;
        @args{qw(hour minute second)} = ( $1, $2, $3 || 0 );
        @args{qw(hour minute second)} = ( 23, 59, 59 ) if $args{hour} > 23;
    }
    else {
        @args{qw(hour minute second)} = ( 0, 0, 0 );
    }

    $args{time_zone} = $this->time_zone;

    DateTime->new(%args);
}

1;
