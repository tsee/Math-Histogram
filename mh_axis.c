#include "mh_axis.h"

bool
mh_axis_create(mh_axis_t **axis, unsigned int nbins, bool varbins)
{
  *axis = (mh_axis_t *)malloc(sizeof(mh_axis_t));
  if (axis == NULL)
    return 0;
  *axis->nbins = nbins;
  if (varbins) {
    *axis->bins = (double *)malloc(sizeof(double) * nbins);
    if (*axis->bins == NULL) {
      free(*axis);
      return 0;
    }
  }
  return 1;
}


bool
mh_axis_clone(mh_axis_t *axis_proto, mh_axis_t **axis_out)
{
  *axis_out = (mh_axis_t *)malloc(sizeof(mh_axis_t));
  if (axis_out == NULL)
    return 0;

  *axis_out->nbins = axis_proto->nbins;
  if (!MH_AXIS_ISFIXBIN(axis_proto)) {
    *axis_out->bins = (double *)malloc(sizeof(double) * axis_proto->nbins);
    if (*axis_out->bins == NULL) {
      free(*axis_out);
      return 0;
    }
    memcpy(*axis_out->bins, axis_proto->bins, sizeof(double) * axis_proto->nbins);
  }
  else {
    *axis_out->bins = NULL;
  }

  *axis_out->binsize = axis_proto->binsize;
  *axis_out->width = axis_proto->width;
  *axis_out->min = axis_proto->min;
  *axis_out->max = axis_proto->max;

  return 1;
}


void
mh_axis_init(mh_axis_t *axis, double min, double max)
{
  axis->min = min;
  axis->max = max;
  axis->width = max-min;
  if (MH_AXIS_ISFIXBIN(axis))
    axis->binsize = width / (double)MH_AXIS_NBINS(axis);
}


void
mh_axis_free(mh_axis_t *axis)
{
  if (MH_AXIS_ISFIXBIN(axis))
    free(axis->bins);
  free(axis);
}


unsigned int
mh_axis_find_bin(mh_axis_t *axis, double x)
{
  if (MH_AXIS_ISFIXBIN(axis))
    return( (x-self->min) / self->binsize );
  else
    return find_bin_nonconstant(x, self->nbins, self->bins);
}


unsigned int
mh_axis_find_bin_var(mh_axis_t *axis, double x)
{
  /* TODO optimize */
  unsigned int mid;
  double mid_val;
  unsigned int imin = 0;
  unsigned int imax = MH_AXIS_NBINS(axis);
  double *bins = axis->bins;

  while (1) {
    mid = imin + (imax-imin)/2;
    mid_val = bins[mid];
    if (mid_val == x)
      return mid;
    else if (mid_val > x) {
      if (mid == 0)
        return 0;
      imax = mid-1;
      if (imin > imax)
        return mid-1;
    }
    else {
      imin = mid+1;
      if (imin > imax)
        return imin-1;
    }
  }
}

