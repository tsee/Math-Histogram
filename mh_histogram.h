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

/* Creates a new histogram with the specified dimensionality and axises.
 * Takes ownership of the (presumably individually allocated) mh_axis_t objects!
 * Does not take ownership of the outer array of pointers.
 */
mh_histogram_t *mh_hist_create(unsigned short ndim, mh_axis_t **axises);

/* Free a histogram */
void mh_hist_free(mh_histogram_t *hist);

/* Given a vector of bin numbers in each dimension, returns the index into
 * the 1D data array. The 1D array includes under- and overflow bins,
 * so the bin numbers are 1-based as usual and include nbins+1 as an
 * overflow. */
unsigned int mh_hist_flat_bin_number(mh_histogram_t *hist, unsigned int dim_bins[]);

/* Calculate and return the total number of bins in a histogram
 * including over- and underflow. */
unsigned int mh_hist_total_nbins(mh_histogram_t *hist);
#endif
