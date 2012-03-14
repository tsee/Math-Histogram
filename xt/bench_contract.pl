use strict;
use warnings;
use Test::More tests => 1;
pass(); # Just in case somebody wants to run this through some TAP thingy

use Math::Histogram qw(make_histogram);
use Benchmark::Dumb qw(cmpthese timethis timethese);

my @axises = ([[1..100]], [100, 0., 1.], [100, 0., 1.], [[1..100]], [100, 0., 1.]);
my $h = make_histogram(@axises);


cmpthese(2000.001, {
  d0 => '$h->contract_dimension(0)',
  d1 => '$h->contract_dimension(1)',
  d2 => '$h->contract_dimension(2)',
  d3 => '$h->contract_dimension(3)',
  d4 => '$h->contract_dimension(4)',
  all => '$h->contract_dimension(0)->contract_dimension(1)->contract_dimension(2)->contract_dimension(3)',
});

