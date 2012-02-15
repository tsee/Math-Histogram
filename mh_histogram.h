#ifndef mh_histogram_h_
#define mh_histogram_h_

#include <mh_axis.h>

typedef struct mh_histogram {
  /* The number of dimensions in the histogram, starting from 0 */
  unsigned short ndim;
  /* The array of axises with ndim elements */
  mh_axis_t *axises;
  /* The actual bins */
  double *data;

  /* content */
  unsigned int nfills;
  /* One overflow/underflow per dimension */
  double *overflow;
  double *underflow;
  /* derived content */
  double total;
} mh_histogram_t;

#define MH_HIST_NDIM(h) ((h)->ndim)

unsigned int mh_hist_bin_number(mh_histogram_t *hist, unsigned int *dim_bins);

#endif
