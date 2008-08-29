# $Id$

package WWW::CybozuOffice6::CalendarDriver;
use strict;
use warnings;

use Carp;

sub new {
    my $class = shift;
    my $driver = bless {}, $class;

    if ( eval('require Text::CSV_XS') ) {
        $driver->{csv} = Text::CSV_XS->new( { binary => 1 } );
    }
    elsif ( eval('require Text::CSV') ) {
        $driver->{csv} = Text::CSV->new();
    }
    confess 'Text::CSV_XS or Text::CSV package is required'
      unless $driver->{csv};

    $driver;
}

1;
