#ifndef mh_axis_h_
#define mh_axis_h_

typedef struct mh_axis {
  double min;
  double max;
  unsigned int nbins;
  
  /* derived */
  double width;
  double binsize;

  /* Exists with nbins+1 elements if we do not have constant binsize, NULL otherwise */
  double *bins;
} mh_axis_t;

/* Returns whether or not a given axis struct has variable bin sizes */
#define MH_AXIS_ISFIXBIN(a) (((a)->bins == NULL)

/* Various accessors for binsizes, bin boundaries, and bin centers.
 * Separate implementations for variable and fixed bin size axis for
 * potential optimization in moving branching outside loops. */
#define MH_AXIS_BINSIZE_FIX(a) ((a)->binsize)
#define MH_AXIS_BINSIZE_VAR(a, ibin) ((a)->bins[ibin])
#define MH_AXIS_BINSIZE(a, ibin) (MH_AXIS_ISFIXBIN(a) ? MH_AXIS_BINSIZE_FIX(a) : MH_AXIS_BINSIZE_VAR((a), (ibin)))

#define MH_AXIS_BIN_LOWER_FIX(a, ibin) ((a)->min + (double)(ibin) * MH_AXIS_BINSIZE_FIX(a))
#define MH_AXIS_BIN_LOWER_VAR(a, ibin) ((a)->bins[ibin])
#define MH_AXIS_BIN_LOWER(a, ibin) (MH_AXIS_ISFIXBIN(a) ? MH_AXIS_BIN_LOWER_FIX((a), (ibin)) : MH_AXIS_BIN_LOWER_VAR((a), (ibin)))

#define MH_AXIS_BIN_UPPER_FIX(a, ibin) ((a)->min + (double)(ibin+1) * MH_AXIS_BINSIZE_FIX(a))
#define MH_AXIS_BIN_UPPER_VAR(a, ibin) ((a)->bins[ibin+1])
#define MH_AXIS_BIN_UPPER(a, ibin) (MH_AXIS_ISFIXBIN(a) ? MH_AXIS_BIN_UPPER_FIX((a), (ibin)) : MH_AXIS_BIN_UPPER_VAR((a), (ibin)))

#define MH_AXIS_BIN_CENTER_FIX(a, ibin) ((a)->min + ((double)(ibin)+0.5) * MH_AXIS_BINSIZE_FIX(a))
#define MH_AXIS_BIN_CENTER_VAR(a, ibin) ( 0.5*((a)->bins[ibin] + (a)->bins[(ibin)+1]) )
#define MH_AXIS_BIN_CENTER(a, ibin) (MH_AXIS_ISFIXBIN(a) ? MH_AXIS_BIN_CENTER_FIX((a), (ibin)) : MH_AXIS_BIN_CENTER_VAR((a), (ibin)))

/*
 * Allocates a new axis struct in the provided pointer.
 * Needs the number of bins in the axis and a boolean indicating
 * whether the axis has variable-size bins for pre-allocation.
 * Returns whether all allocations succeeded.
 */
bool mh_axis_create(mh_axis_t **axis, bool zero, unsigned int nbins, bool varbins);
/* Deallocates an axis struct */
void mh_axis_free(mh_axis_t *axis);
/* Clones an axis */
bool mh_axis_clone(mh_axis_t *axis_proto, mh_axis_t **axis_out);

/* Returns the bin number where x would be filled into the given
 * axis abstracts away whether to use constant or non-constant
 * bin sizes. */
unsigned int mh_axis_find_bin(mh_axis_t *axis, double x);

/* optimized version for fixed-bin-only case */
#define MH_AXIS_FIND_BIN_FIX(a, x) ( ((x)-(a)->min) / MH_AXIS_BINSIZE_FIX(a) )
/* variable bin size bin finder, O(log N) */
unsigned int mh_axis_find_bin_var(mh_axis_t *axis, double x);

#endif
