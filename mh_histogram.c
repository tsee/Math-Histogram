#include "mh_histogram.h"

#include <stdio.h>
#include <stdlib.h>

mh_histogram_t *
mh_hist_create(unsigned short ndim, mh_axis_t **axises)
{
  unsigned int nbins, i;
  mh_histogram_t *hist = malloc(sizeof(mh_histogram_t));
  if (hist == NULL)
    return NULL;
  hist->ndim = ndim;

  hist->axises = malloc(sizeof(mh_axis_t *) * ndim);
  if (hist == NULL) {
    free(hist);
    return NULL;
  }
  for (i = 0; i < ndim; ++i)
    hist->axises[i] = axises[i];

  nbins = mh_hist_total_nbins(hist);
  hist->data = (double *)calloc(nbins, sizeof(double));
  if (hist->data == NULL) {
    free(hist->axises);
    free(hist);
    return NULL;
  }

  /* TODO should initialization live elsewhere? */
  hist->total = 0.;
  hist->nfills = 0;

  return hist;
}


void
mh_hist_free(mh_histogram_t *hist)
{
  unsigned int i, ndim = MH_HIST_NDIM(hist);
  mh_axis_t **axises = hist->axises;
  for (i = 0; i < ndim; ++i)
    mh_axis_free(axises[i]);

  free(hist->axises);
  free(hist->data);
  free(hist);
}


unsigned int
mh_hist_flat_bin_number(mh_histogram_t *hist, unsigned int dim_bins[])
{
  const unsigned short ndim = MH_HIST_NDIM(hist);
  if (ndim == 1)
    return dim_bins[0];
  else {
    register unsigned int bin_index;
    register int i;
    mh_axis_t **axises = hist->axises;

    /* Suppose we have dim_bins = {5, 3, 4};
     * Then the index into the 1D data array is
     *   4 * (dim_bins[2]+2)^2 + 3 * (dim_bins[1]+2)^1 + 5 * (dim_bins[0]+2)^0
     * which can be done more efficiently as
     *   ((4)*dim_bins[2] + 3)*dim_bins[1] + 5;
     * parenthesis included to hint at the execution order.
     */
    /* FIXME THIS IS BROKEN? */
    bin_index = dim_bins[ndim-1];
    /* printf("%u %u\n", bin_index, ndim); */
    for (i = (int)ndim-2; i >= 0; --i)
      bin_index = bin_index*(MH_AXIS_NBINS(axises[i])+2) + dim_bins[i];
  
    return bin_index;
  }
}


unsigned int
mh_hist_total_nbins(mh_histogram_t *hist)
{
  unsigned int i;
  unsigned int bins = 1;
  unsigned int ndim = MH_HIST_NDIM(hist);
  mh_axis_t **axises = hist->axises;

  for (i = 0; i < ndim; ++i)
    bins *= MH_AXIS_NBINS(axises[i])+2;
  /* printf("Total number of bins: %u\n", bins); */
  return bins;
}

