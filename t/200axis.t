use strict;
use warnings;
use Math::Histogram;
use Test::More;

my $ax = Math::Histogram::Axis->new(4, 0., 1.);
isa_ok($ax, 'Math::Histogram::Axis');

done_testing();
