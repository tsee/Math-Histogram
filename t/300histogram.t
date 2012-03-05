use strict;
use warnings;
use Math::Histogram qw(make_histogram);
use Test::More;

my @axis_specs = ([2, 0., 1.], [10000, 0., 1.], [[1., 2., 3., 4., 5.]]);
test_histogram(\@axis_specs, 0);
test_histogram(\@axis_specs, 1);

done_testing();

sub test_histogram {
  my $specs = shift;
  my $do_clone = shift;

  my @axis_defs = @$specs;
  my $h = make_histogram(@axis_defs);
  $h = $h->clone if $do_clone;
  isa_ok($h, 'Math::Histogram');

  my @axis = map $h->get_axis($_), 0..2;
  is(scalar(@axis), 3);
  isa_ok($_, 'Math::Histogram::Axis') for @axis;

  foreach my $iax (0..$#axis) {
    my $ax = $axis[$iax];
    my $spec = $axis_defs[$iax];
    if (ref($spec->[0])) { # varbins
      my $s = $spec->[0];
      is($ax->nbins, scalar(@$s)-1, "dim $iax, nbins");
      is_approx($ax->min, $s->[0], "dim $iax, min");
      is_approx($ax->max, $s->[-1], "dim $iax, max");
    }
    else { # fixbins
      is($ax->nbins, $spec->[0], "dim $iax, nbins");
      is_approx($ax->min, $spec->[1], "dim $iax, min");
      is_approx($ax->max, $spec->[2], "dim $iax, max");
    }
  }

}

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
