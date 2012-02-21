#include <stdio.h>
#include <stdlib.h>
#include <mh_histogram.h>
#include <mh_axis.h>

#include "mytap.h"

mh_histogram_t *
make_cubything_hist(unsigned int ndim)
{
  unsigned int i;
  mh_histogram_t *h;
  unsigned int nbins = 2;
  mh_axis_t **axises = malloc(ndim * sizeof(mh_axis_t *));
  for (i = 0; i < ndim; ++i) {
    axises[i] = mh_axis_create(nbins+i, MH_AXIS_OPT_FIXEDBINS);
    mh_axis_init(axises[i], 0., 1.);
  }

  h = mh_hist_create(ndim, axises);
  free(axises);
  return h;
}

int
main (int argc, char **argv)
{
  unsigned int i, x, y, z;
  mh_histogram_t *h1;
  mh_histogram_t *h2;
  mh_histogram_t *h3;
  unsigned int dim_bins1[1];
  unsigned int dim_bins2[2];
  unsigned int dim_bins3[3];
  char buf[2048];
  char dimbuf[2048];

  UNUSED(argc);
  UNUSED(argv);
  ok(1);

  h1 = make_cubything_hist(1);
  for (i = 0; i <= 3; ++i) {
    dim_bins1[0] = i;
    ok_m(i == mh_hist_flat_bin_number(h1, dim_bins1), "1d cubything");
  }
  
  h2 = make_cubything_hist(2);
  for (y = 0; y <= 4; ++y) {
    dim_bins2[1] = y;
    for (x = 0; x <= 3; ++x) {
      dim_bins2[0] = x;
      ok_m(x + y*(3+2) == mh_hist_flat_bin_number(h2, dim_bins2), "2d cubything");
    }
  }

  h3 = make_cubything_hist(3);
  sprintf(dimbuf, "with o/u xbins=%u, ybins=%u, zbins=%u", 2+MH_AXIS_NBINS(h3->axises[0]), 2+MH_AXIS_NBINS(h3->axises[1]), 2+MH_AXIS_NBINS(h3->axises[2]));
  for (z = 0; z <= 5; ++z) {
    dim_bins3[2] = z;
    for (y = 0; y <= 4; ++y) {
      dim_bins3[1] = y;
      for (x = 0; x <= 3; ++x) {
        unsigned int exp = x + y*(3+2) + z*(4+2)*(3+2);
        dim_bins3[0] = x;
        sprintf(buf, "3d cubything, x=%u y=%u z=%u, res=%u exp=%u, (%s)", x, y, z, mh_hist_flat_bin_number(h3, dim_bins3), exp, dimbuf);
        ok_m(exp == mh_hist_flat_bin_number(h3, dim_bins3), buf);
      }
    }
  }

  mh_hist_free(h1);
  mh_hist_free(h2);
  mh_hist_free(h3);

  done_testing();
  return 0;
}

