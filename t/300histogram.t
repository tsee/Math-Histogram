use strict;
use warnings;
use Math::Histogram qw(make_histogram);
use Test::More;

my $h = make_histogram([2, 0., 1.], [10000, 0., 1.], [[1., 2., 3., 4., 5.]]);
isa_ok($h, 'Math::Histogram');

done_testing();

sub is_approx {
  my ($l, $r, $m) = @_;
  my $is_undef = !defined($l) || !defined($r);
  $l = "<undef>" if not defined $l;
  $r = "<undef>" if not defined $r;
  ok(
    !$is_undef
    && $l+1e-15 > $r
    && $l-1e-15 < $r,
    $m
  )
  or note("'$m' failed: $l != $r");
}
