#include <stdio.h>
#include <stdlib.h>
#include <mh_histogram.h>
#include <mh_axis.h>

#include "mytap.h"


void test_flat_bin_number();
mh_histogram_t *make_cubything_hist(unsigned int ndim, int varbins);
mh_histogram_t *histogram_clone_dance(mh_histogram_t *input);

int
main (int argc, char **argv)
{
  UNUSED(argc);
  UNUSED(argv);
  pass();

  /* without (0) and with (1) cloning */
  test_flat_bin_number(0, MH_AXIS_OPT_FIXEDBINS);
  test_flat_bin_number(1, MH_AXIS_OPT_FIXEDBINS);
  test_flat_bin_number(0, MH_AXIS_OPT_VARBINS);
  test_flat_bin_number(1, MH_AXIS_OPT_VARBINS);

  done_testing();
  return 0;
}


void test_flat_bin_number(int do_clone, int varbins)
{
  unsigned int i, x, y, z, prev_bin_no;
  mh_histogram_t *h1;
  mh_histogram_t *h2;
  mh_histogram_t *h3;
  unsigned int dim_bins1[1];
  unsigned int dim_bins2[2];
  unsigned int dim_bins3[3];
  unsigned int dim_bins_buf[3];
  double coord1[1];
  double coord2[2];
  double coord3[3];
  char buf[2048];
  char dimbuf[2048];

  h1 = make_cubything_hist(1, varbins);
  if (do_clone != 0)
    h1 = histogram_clone_dance(h1);
  for (i = 0; i <= 3; ++i) {
    dim_bins1[0] = i;
    coord1[0] = (double)i/2.- 1e-5;
    is_int_m(mh_hist_flat_bin_number(h1, dim_bins1), i, "1d cubything");
    is_int_m(mh_hist_find_bin(h1, coord1), i, "1d cubything, from coord");
    mh_hist_find_bin_numbers(h1, coord1, dim_bins_buf);
    is_int_m(dim_bins_buf[0], i, "1d cubything finding bin nums. from coords");
    is_int_m(mh_hist_find_bin_buf(h1, coord1, dim_bins_buf), i, "1d cubything, from coord buf");
  }
  
  h2 = make_cubything_hist(2, varbins);
  if (do_clone != 0)
    h2 = histogram_clone_dance(h2);
  sprintf(dimbuf, "with o/u: xbins=%u, ybins=%u", 2+MH_AXIS_NBINS(h2->axises[0]), 2+MH_AXIS_NBINS(h2->axises[1]));
  prev_bin_no = 0;
  for (y = 0; y <= 4; ++y) {
    dim_bins2[1] = y;
    for (x = 0; x <= 3; ++x) {
      const unsigned int exp = x + y*(2+2);
      if (x != 0 || y != 0)
        is_int_m(exp, prev_bin_no+1, "contiguous bins");
      prev_bin_no = exp;
      dim_bins2[0] = x;
      coord2[0] = (double)x/2. - 1e-5;
      coord2[1] = (double)y/3. - 1e-5;
      sprintf(buf, "2d cubything, x=%u y=%u, res=%u exp=%u, (%s)", x, y, mh_hist_flat_bin_number(h2, dim_bins2), exp, dimbuf);
      is_int_m(mh_hist_flat_bin_number(h2, dim_bins2), exp, buf);
      is_int_m(mh_hist_find_bin(h2, coord2), exp, buf);
      mh_hist_find_bin_numbers(h2, coord2, dim_bins_buf);
      is_int(dim_bins_buf[0], x);
      is_int(dim_bins_buf[1], y);
      is_int_m(mh_hist_find_bin_buf(h2, coord2, dim_bins_buf), exp, buf);
    }
  }

  h3 = make_cubything_hist(3, varbins);
  if (do_clone != 0)
    h3 = histogram_clone_dance(h3);
  sprintf(dimbuf, "with o/u: xbins=%u, ybins=%u, zbins=%u", 2+MH_AXIS_NBINS(h3->axises[0]), 2+MH_AXIS_NBINS(h3->axises[1]), 2+MH_AXIS_NBINS(h3->axises[2]));
  for (z = 0; z <= 5; ++z) {
    dim_bins3[2] = z;
    for (y = 0; y <= 4; ++y) {
      dim_bins3[1] = y;
      for (x = 0; x <= 3; ++x) {
        const unsigned int exp = x + y*(2+2) + z*(3+2)*(2+2);
        if (x != 0 || y != 0 || z != 0)
          is_int_m(exp, prev_bin_no+1, "contiguous bins");
        prev_bin_no = exp;
        dim_bins3[0] = x;
        coord3[0] = (double)x/2. - 1e-5;
        coord3[1] = (double)y/3. - 1e-5;
        coord3[2] = (double)z/4. - 1e-5;
        sprintf(buf, "3d cubything, x=%u y=%u z=%u, res=%u exp=%u, (%s)", x, y, z, mh_hist_flat_bin_number(h3, dim_bins3), exp, dimbuf);
        is_int_m(mh_hist_flat_bin_number(h3, dim_bins3), exp, buf);

        is_int_m(mh_hist_find_bin(h3, coord3), exp, buf);
        mh_hist_find_bin_numbers(h3, coord3, dim_bins_buf);
        is_int(dim_bins_buf[0], x);
        is_int(dim_bins_buf[1], y);
        is_int(dim_bins_buf[2], z);
        is_int_m(mh_hist_find_bin_buf(h3, coord3, dim_bins_buf), exp, buf);
      }
    }
  }

  mh_hist_free(h1);
  mh_hist_free(h2);
  mh_hist_free(h3);
}


mh_histogram_t *
histogram_clone_dance(mh_histogram_t *input)
{
  mh_histogram_t *cl = mh_hist_clone(input, 0);
  mh_hist_free(input);
  input = mh_hist_clone(cl, 1);
  mh_hist_free(cl);
  return input;
}


mh_histogram_t *
make_cubything_hist(unsigned int ndim, int varbins)
{
  unsigned int i, j;
  mh_histogram_t *h;
  unsigned int nbins = 2;
  mh_axis_t **axises = malloc(ndim * sizeof(mh_axis_t *));
  for (i = 0; i < ndim; ++i) {
    axises[i] = mh_axis_create(nbins+i, varbins);
    if (axises[i] == NULL) {
      fail("Failed to malloc axis!");
      return NULL;
    }
    mh_axis_init(axises[i], 0., 1.);
    if (varbins == MH_AXIS_OPT_VARBINS) {
      double *b = axises[i]->bins;
      for (j = 0; j <= nbins+i; ++j) {
        b[j] = 0. + (double)j/(nbins+i);
        /* printf("  i = %u   j = %u   =>   %f\n", i, j, b[j]); */
      }
    }
  }

  h = mh_hist_create(ndim, axises);
  free(axises);
  return h;
}
