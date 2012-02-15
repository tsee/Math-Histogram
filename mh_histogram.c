#include "mh_histogram.h"

#include <stdio.h>

unsigned int
mh_hist_bin_number(mh_histogram_t *hist, unsigned int *dim_bins)
{
  const unsigned short ndim = MH_HIST_NDIM(hist);
  if (ndim == 1)
    return dim_bins[0];
  else {
    register unsigned int bin_index;
    register int i;

    /* Suppose we have dim_bins = {5, 3, 4};
     * Then the index into the 1D data array is
     *   4 * ndims^2 + 3 * ndims^1 + 5 * ndims^0
     * which can be done more efficiently as
     *   ((4)*nbins + 3)*nbins + 5;
     * parenthesis included to hint at the execution order.
     */
    bin_index = dim_bins[ndim-1];
    for (i = (int)ndim-2; i >= 0; --i)
      bin_index = bin_index*ndim + dim_bins[i];
  
    return bin_index;
  }
}

