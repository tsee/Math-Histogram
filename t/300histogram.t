use strict;
use warnings;
use Math::Histogram qw(make_histogram);
use Test::More;
use File::Spec;

BEGIN { push @INC, -d "t" ? File::Spec->catdir(qw(t lib)) : "lib"; }
use Math::Histogram::Test;

my @axis_specs = ([2, 0., 1.], [100, 0., 1.], [[1., 2., 3., 4., 5.]]);
test_histogram(\@axis_specs, 0);
test_histogram(\@axis_specs, 1);

done_testing();

sub test_histogram {
  my $specs = shift;
  my $do_clone = shift;

  my $h = make_histogram(@$specs);
  $h = $h->clone if $do_clone;
  isa_ok($h, 'Math::Histogram');

  test_hist_axises($h, $specs);

  is($h->ndim, 3, "ndim");
  is($h->nfills, 0, "nfills");
  is_approx($h->total, 0., "total");
}

sub test_hist_axises {
  my $h = shift;
  my $specs = shift;

  my @axis_defs = @$specs;

  my @axis = map $h->get_axis($_), 0..2;
  my @ref_axis = map Math::Histogram::Axis->new(@$_), @$specs;
  foreach (0..2) {
    axis_eq($axis[$_], $ref_axis[$_], "axis " . ($_+1));
  }
}

