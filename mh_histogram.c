#include "mh_histogram.h"

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <float.h>

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

  hist->arg_coord_buffer = malloc(sizeof(double) * ndim);
  if (hist->arg_coord_buffer == NULL) {
    free(hist);
    free(hist->bin_buffer);
    return NULL;
  }


  hist->axises = malloc(sizeof(mh_axis_t *) * ndim);
  if (hist->axises == NULL) {
    free(hist->bin_buffer);
    free(hist->arg_coord_buffer);
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
    free(hist->arg_coord_buffer);
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

  hist->arg_coord_buffer = malloc(sizeof(double) * hist->ndim);
  if (hist->arg_coord_buffer == NULL) {
    free(hist->bin_buffer);
    free(hist->arg_coord_buffer);
    free(hist);
    return NULL;
  }

  hist->axises = malloc(sizeof(mh_axis_t *) * MH_HIST_NDIM(hist));
  if (hist->axises == NULL) {
    free(hist->bin_buffer);
    free(hist->arg_coord_buffer);
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
      free(hist->arg_coord_buffer);
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
      free(hist->arg_coord_buffer);
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
  free(hist->arg_coord_buffer);
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
  hist->total += content - old;
}


double
mh_hist_get_bin_content(mh_histogram_t *hist, unsigned int dim_bins[])
{
  return hist->data[mh_hist_flat_bin_number(hist, dim_bins)];
}


mh_histogram_t *
mh_hist_contract_dimension(mh_histogram_t *hist, unsigned int contracted_dimension)
{
  mh_axis_t **axises;
  mh_axis_t **new_hist_axises;
  mh_histogram_t *outhist;
  unsigned int i, j, linear_nbins, ilinear;
  unsigned int *dimension_map;
  unsigned int *dim_bin_buffer;
  unsigned int *reduced_dim_bin_buffer;
  unsigned int ndims = MH_HIST_NDIM(hist);

  if (ndims == 1 || contracted_dimension >= ndims)
    return NULL;

  axises = hist->axises;

  /* Mapping from reduced dimension number to original
   * dimension number, so from destination to source. */
  dimension_map = malloc(sizeof(unsigned int) * (ndims-1));
  /* Setup array of cloned axises for the new histogram. */
  new_hist_axises = malloc(sizeof(mh_axis_t *) * (ndims-1));
  j = 0;
  for (i = 0; i < ndims; ++i) {
    if (i == contracted_dimension) { /* FIXME there must be a better way */
      j = 1;
      continue;
    }
    dimension_map[i-j] = i;
    new_hist_axises[i-j] = mh_axis_clone(axises[i]);
    if (new_hist_axises[i-j] == NULL) {
      ndims = i-j; /* abuse for emergency cleanup */
      for (i = 0; i < ndims; ++i)
        free(new_hist_axises[i]);
      free(new_hist_axises);
      free(dimension_map);
      return NULL;
    }
  }

  /* Create output N-1 dimensional histogram. */
  outhist = mh_hist_create(ndims-1, new_hist_axises);
  free(new_hist_axises);

  dim_bin_buffer = malloc(ndims * sizeof(unsigned int));
  reduced_dim_bin_buffer = malloc((ndims-1) * sizeof(unsigned int));

  /* - Iterate over all bins in the source histogram.
   *   - Find the vector of bin indexes in each dimension.
   *   - Copy the bin indexes over to the N-1 dimensional vector.
   *   - Use that vector to write the original bin's content to the
   *     right bin in the output histogram.
   *
   * This isn't hugely efficient but nicely abstracts away the problem
   * with N/N-1 dimensionality by having the dimension mapping in a data
   * structure (dimension_map) and simply skipping a dimension to contract.
   */
  /* TODO allow skipping of overflow/underflow in contraction somehow?
   * TODO generic mechanism for contracting only a range of bins?
   */
  linear_nbins = mh_hist_total_nbins(hist);
  for (ilinear = 0; ilinear < linear_nbins; ++ilinear) {
    /* Get the [ix, iy, iz, ...] N-dim bin numbers from the linear bin. */
    mh_hist_flat_bin_number_to_dim_bins(hist, ilinear, dim_bin_buffer);

    /* Copy all dimension indexes but the one we're contracting. */
    for (i = 0; i < ndims-1; ++i)
      reduced_dim_bin_buffer[i] = dim_bin_buffer[ dimension_map[i] ];

    /* direct access to hist->data since we're iterating in linearized bins already */
    mh_hist_fill_bin_w(outhist, reduced_dim_bin_buffer, hist->data[ilinear]);
  }

  free(dim_bin_buffer);
  free(reduced_dim_bin_buffer);

  /* fix the number of fills */
  outhist->nfills = hist->nfills;

  return outhist;
}


int
mh_hist_data_equal_eps(mh_histogram_t *left, mh_histogram_t *right, double epsilon)
{
  const unsigned int total_nbins_left = mh_hist_total_nbins(left);
  const unsigned int total_nbins_right = mh_hist_total_nbins(right);
  unsigned int i;
  double *data_left = left->data;
  double *data_right = right->data;

  if (total_nbins_left != total_nbins_right)
    return 0;

  for (i = 0; i < total_nbins_left; ++i) {
    if (   data_left[i] + epsilon < data_right[i]
        || data_left[i] - epsilon > data_right[i])
      return 0;
  }

  return 1;
}

int
mh_hist_data_equal(mh_histogram_t *left, mh_histogram_t *right)
{
  return mh_hist_data_equal_eps(left, right, DBL_EPSILON);
}
