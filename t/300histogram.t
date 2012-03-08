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

  my @test_bins = (
    { in   => [0., 0., 1.],
      out  => [1, 1, 1],
      name => "start of first bins" },
    { in   => [0.49, 1/100-1e-6, 1.999],
      out  => [1, 1, 1],
      name => "end of first bins" },
    { in   => [0.5, 1/100, 2],
      out  => [2, 2, 2],
      name => "lower bound of second bin" },
    { in   => [1.-1e-9, 1.-1e-9, 5-1e-9],
      out  => [2, 100, 4],
      name => "almost upper bound of last bin" },
    { in   => [1000., 100., 500],
      out  => [3, 101, 5],
      name => "overflow" },
    { in   => [1., 1., 5],
      out  => [3, 101, 5],
      name => "barely overflow" },
    { in   => [-1., -0.1, 0.],
      out  => [0, 0, 0],
      name => "underflow" },
    { in   => [-1e-9, -1e-9, 1.-1e-9],
      out  => [0, 0, 0],
      name => "barely underflow" },
  );
  foreach my $t (@test_bins) {
    my $b = $h->find_bin_numbers($t->{in});
    is_deeply($b, $t->{out}, "Finding bins tests: $t->{name}");
  }
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

