#include "mh_histogram.h"

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

mh_histogram_t *
mh_hist_create(unsigned short ndim, mh_axis_t **axises)
{
  unsigned int nbins, i;
  mh_histogram_t *hist = malloc(sizeof(mh_histogram_t));
  if (hist == NULL)
    return NULL;
  hist->ndim = ndim;

  hist->bin_buffer = malloc(sizeof(unsigned int) * ndim * 2);
  if (hist->bin_buffer == NULL) {
    free(hist);
    return NULL;
  }

  /* share the alloc/free */
  hist->arg_bin_buffer = &hist->bin_buffer[ndim];

  hist->axises = malloc(sizeof(mh_axis_t *) * ndim);
  if (hist->axises == NULL) {
    free(hist->bin_buffer);
    free(hist);
    return NULL;
  }
  for (i = 0; i < ndim; ++i)
    hist->axises[i] = axises[i];

  nbins = mh_hist_total_nbins(hist);
  hist->data = (double *)calloc(nbins, sizeof(double));
  if (hist->data == NULL) {
    free(hist->bin_buffer);
    free(hist->axises);
    free(hist);
    return NULL;
  }

  /* TODO should initialization live elsewhere? */
  hist->total = 0.;
  hist->nfills = 0;

  return hist;
}

mh_histogram_t *
mh_hist_clone(mh_histogram_t *hist_proto, int do_copy_data)
{
  unsigned int nbins, i;
  mh_histogram_t *hist = malloc(sizeof(mh_histogram_t));
  if (hist == NULL)
    return NULL;
  hist->ndim = MH_HIST_NDIM(hist_proto);

  hist->bin_buffer = malloc(sizeof(unsigned int) * MH_HIST_NDIM(hist) * 2);
  if (hist->bin_buffer == NULL) {
    free(hist);
    return NULL;
  }

  /* share the alloc/free */
  hist->arg_bin_buffer = &(hist->bin_buffer[MH_HIST_NDIM(hist)]);


  hist->axises = malloc(sizeof(mh_axis_t *) * MH_HIST_NDIM(hist));
  if (hist->axises == NULL) {
    free(hist->bin_buffer);
    free(hist);
    return NULL;
  }
  for (i = 0; i < hist->ndim; ++i)
    hist->axises[i] = mh_axis_clone(hist_proto->axises[i]);

  nbins = mh_hist_total_nbins(hist_proto);
  if (do_copy_data != 0) {
    hist->data = (double *)malloc(nbins * sizeof(double));
    if (hist->data == NULL) {
      free(hist->bin_buffer);
      free(hist->axises);
      free(hist);
      return NULL;
    }
    memcpy(hist->data, hist_proto->data, nbins * sizeof(double));

    /* TODO should initialization live elsewhere? */
    hist->total = MH_HIST_TOTAL(hist_proto);
    hist->nfills = MH_HIST_NFILLS(hist_proto);
  }
  else {
    hist->data = (double *)calloc(nbins, sizeof(double));
    if (hist->data == NULL) {
      free(hist->bin_buffer);
      free(hist->axises);
      free(hist);
      return NULL;
    }
    /* TODO should initialization live elsewhere? */
    hist->total = 0.;
    hist->nfills = 0;
  }

  return hist;
}


void
mh_hist_free(mh_histogram_t *hist)
{
  unsigned int i, ndim = MH_HIST_NDIM(hist);
  mh_axis_t **axises = hist->axises;
  for (i = 0; i < ndim; ++i)
    mh_axis_free(axises[i]);

  free(hist->bin_buffer); /* frees arg_bin_buffer as well */
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
     *   4 * (dim_bins[2]+2)*(dim_bins[1]+2) + 3 * (dim_bins[1]+2) + 5
     * which can be done more efficiently as
     *   ((4)*(dim_bins[2]+2) + 3)*(dim_bins[1]+2) + 5;
     * parenthesis hint at the execution order.
     */

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


void
mh_hist_find_bin_numbers(mh_histogram_t *hist, double coord[], unsigned int bin[])
{
  const unsigned int ndim = MH_HIST_NDIM(hist);
  unsigned int i;
  mh_axis_t **axises = hist->axises;
  for (i = 0; i < ndim; ++i) {
    bin[i] = mh_axis_find_bin(axises[i], coord[i]);
  }
}


unsigned int
mh_hist_find_bin(mh_histogram_t *hist, double coord[])
{
  mh_hist_find_bin_numbers(hist, coord, hist->bin_buffer);
  return mh_hist_flat_bin_number(hist, hist->bin_buffer);
}


unsigned int
mh_hist_find_bin_buf(mh_histogram_t *hist, double coord[], unsigned int bin_number_buffer[])
{
  mh_hist_find_bin_numbers(hist, coord, bin_number_buffer);
  return mh_hist_flat_bin_number(hist, bin_number_buffer);
}


void
mh_hist_flat_bin_number_to_dim_bins(mh_histogram_t *hist,
                                    unsigned int flat_bin,
                                    unsigned int dim_bins[])
{
  const unsigned short ndim = MH_HIST_NDIM(hist);
  if (ndim == 1)
    dim_bins[0] = flat_bin;
  else {
    register int i, nbins;
    register mh_axis_t **axises = hist->axises;

    for (i = 0; i < ndim; ++i) {
      nbins = MH_AXIS_NBINS(axises[i])+2;
      dim_bins[i] = flat_bin % nbins;
      flat_bin = (flat_bin - dim_bins[i]) / nbins;
    }
  }
}


unsigned int
mh_hist_fill(mh_histogram_t *hist, double x[])
{
  const unsigned int flat_bin = mh_hist_find_bin(hist, x);
  hist->data[flat_bin] += 1;
  hist->total += 1;
  hist->nfills++;
  return flat_bin;
}


unsigned int
mh_hist_fill_bin(mh_histogram_t *hist, unsigned int dim_bins[])
{
  const unsigned int flat_bin = mh_hist_flat_bin_number(hist, dim_bins);
  hist->data[flat_bin] += 1;
  hist->total += 1;
  hist->nfills++;
  return flat_bin;
}


unsigned int
mh_hist_fill_w(mh_histogram_t *hist, double x[], double weight)
{
  const unsigned int flat_bin = mh_hist_find_bin(hist, x);
  hist->data[flat_bin] += weight;
  hist->total += weight;
  hist->nfills++;
  return flat_bin;
}


unsigned int
mh_hist_fill_bin_w(mh_histogram_t *hist, unsigned int dim_bins[], double weight)
{
  const unsigned int flat_bin = mh_hist_flat_bin_number(hist, dim_bins);
  hist->data[flat_bin] += weight;
  hist->total += weight;
  hist->nfills++;
  return flat_bin;
}


void
mh_hist_fill_n(mh_histogram_t *hist, unsigned int n, double **xs)
{
  register unsigned int flat_bin;
  register unsigned int i;
  for (i = 0; i < n; ++i) {
    flat_bin = mh_hist_find_bin(hist, xs[i]);
    hist->data[flat_bin] += 1;
  }
  hist->nfills += n;
  hist->total += n;
}


void
mh_hist_fill_bin_n(mh_histogram_t *hist, unsigned int n, unsigned int **dim_bins)
{
  register unsigned int flat_bin;
  register unsigned int i;
  for (i = 0; i < n; ++i) {
    flat_bin = mh_hist_flat_bin_number(hist, dim_bins[i]);
    hist->data[flat_bin] += 1;
  }
  hist->nfills += n;
  hist->total += n;
}


void
mh_hist_fill_nw(mh_histogram_t *hist, unsigned int n, double **xs, double weights[])
{
  register unsigned int flat_bin;
  register unsigned int i;
  double w;
  for (i = 0; i < n; ++i) {
    w = weights[i];
    flat_bin = mh_hist_find_bin(hist, xs[i]);
    hist->data[flat_bin] += w;
    hist->nfills += w;
    hist->total += w;
  }
}


void
mh_hist_fill_bin_nw(mh_histogram_t *hist, unsigned int n, unsigned int **dim_bins, double weights[])
{
  register unsigned int flat_bin;
  register unsigned int i;
  double w;
  for (i = 0; i < n; ++i) {
    w = weights[i];
    flat_bin = mh_hist_flat_bin_number(hist, dim_bins[i]);
    hist->data[flat_bin] += w;
    hist->nfills += w;
    hist->total += w;
  }
}


void
mh_hist_set_bin_content(mh_histogram_t *hist, unsigned int dim_bins[], double content)
{
  unsigned int flat_bin = mh_hist_flat_bin_number(hist, dim_bins);
  double old = hist->data[flat_bin];
  hist->data[flat_bin] = content;
  hist->total =+ content - old;
}


double
mh_hist_get_bin_content(mh_histogram_t *hist, unsigned int dim_bins[])
{
  return hist->data[mh_hist_flat_bin_number(hist, dim_bins)];
}

