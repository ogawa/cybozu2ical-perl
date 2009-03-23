# $Id$

package WWW::CybozuOffice6::CalendarDriver;
use strict;
use warnings;

use Carp;

sub new {
    my $class = shift;
    my $driver = bless {}, $class;

    eval 'use Text::CSV 1';
    if ($@) {
        confess $@;
    }
    $driver->{csv} = Text::CSV->new( { binary => 1 } );
    $driver;
}

1;
