#ifndef mh_histogram_h_
#define mh_histogram_h_

#include <mh_axis.h>

typedef struct mh_histogram {
  /* The number of dimensions in the histogram, starting from 0 */
  unsigned short ndim;
  /* The array of axises with ndim elements */
  mh_axis_t **axises;
  /* The actual bins */
  double *data;

  /* content */
  unsigned int nfills;

  /* derived content */
  double total;
} mh_histogram_t;

#define MH_HIST_NDIM(h) ((h)->ndim)
#define MH_HIST_OVERFLOW(h, i) ((h)->ndim)

#define MH_HIST_TOTAL(h) ((h)->total)
#define MH_HIST_NFILLS(h) ((h)->nfills)

/* Creates a new histogram with the specified dimensionality and axises.
 * Takes ownership of the (presumably individually allocated) mh_axis_t objects!
 * Does not take ownership of the outer array of pointers.
 */
mh_histogram_t *mh_hist_create(unsigned short ndim, mh_axis_t **axises);

/* Clones a full histogram. If do_copy_data isn't set, zeroes the data array,
 * creating an empty clone.. */
mh_histogram_t *mh_hist_clone(mh_histogram_t *hist_proto, int do_copy_data);

/* Free a histogram */
void mh_hist_free(mh_histogram_t *hist);

/* Given a vector of bin numbers in each dimension, returns the index into
 * the 1D data array. The 1D array includes under- and overflow bins,
 * so the bin numbers are 1-based as usual and include nbins+1 as an
 * overflow. */
unsigned int mh_hist_flat_bin_number(mh_histogram_t *hist, unsigned int dim_bins[]);

/* TODO implement reverse of mh_hist_flat_bin_number: flat number to double[ndims] */

/* Calculate and return the total number of bins in a histogram
 * including over- and underflow. */
unsigned int mh_hist_total_nbins(mh_histogram_t *hist);

/* Finds the set of bin numbers from a set of coordinates. Allocations are resp. of caller. */
void mh_hist_find_bin_numbers(mh_histogram_t *hist, double coord[], unsigned int bin[]);

/* Given an array of ndim coordinates, finds the internal bin id in the histogram.
 * mh_hist_find_bin_buf does the same but can be more efficient if you have a buffer
 * available for ndim unsigned ints since it avoids doing any heap allocations. */
unsigned int mh_hist_find_bin(mh_histogram_t *hist, double coord[]);
unsigned int mh_hist_find_bin_buf(mh_histogram_t *hist, double coord[], unsigned int bin_number_buffer[]);

#endif
