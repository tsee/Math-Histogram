#include "mh_axis.h"

#include <stdlib.h>
#include <string.h>

mh_axis_t *
mh_axis_create(unsigned int nbins, unsigned short have_varbins)
{
  mh_axis_t *axis;
  axis = (mh_axis_t *)malloc(sizeof(mh_axis_t));
  if (axis == NULL)
    return NULL;
  axis->nbins = nbins;

  if (have_varbins != MH_AXIS_OPT_FIXEDBINS) {
    axis->bins = (double *)malloc(sizeof(double) * nbins);
    if (axis->bins == NULL) {
      free(axis);
      return NULL;
    }
  }

  return axis;
}


mh_axis_t *
mh_axis_clone(mh_axis_t *axis_proto)
{
  mh_axis_t *axis_out = (mh_axis_t *)malloc(sizeof(mh_axis_t));
  if (axis_out == NULL)
    return NULL;

  axis_out->nbins = axis_proto->nbins;
  if (!MH_AXIS_ISFIXBIN(axis_proto)) {
    axis_out->bins = (double *)malloc(sizeof(double) * axis_proto->nbins);
    if (axis_out->bins == NULL) {
      free(axis_out);
      return NULL;
    }
    memcpy(axis_out->bins, axis_proto->bins, sizeof(double) * axis_proto->nbins);
  }
  else {
    axis_out->bins = NULL;
  }

  axis_out->binsize = axis_proto->binsize;
  axis_out->width = axis_proto->width;
  axis_out->min = axis_proto->min;
  axis_out->max = axis_proto->max;

  return axis_out;
}


void
mh_axis_init(mh_axis_t *axis, double min, double max)
{
  axis->min = min;
  axis->max = max;
  axis->width = max-min;
  if (MH_AXIS_ISFIXBIN(axis))
    axis->binsize = axis->width / (double)MH_AXIS_NBINS(axis);
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
  if (MH_AXIS_ISFIXBIN(axis)) {
    double min = MH_AXIS_MIN(axis);
    if (x < min)
      return 0;
    else if (x > MH_AXIS_MAX(axis))
      return MH_AXIS_NBINS(axis)+1;
    return( (unsigned int) ((x-MH_AXIS_MIN(axis)) / MH_AXIS_BINSIZE_FIX(axis)) );
  }
  else
    return mh_axis_find_bin_var(axis, x);
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

  if (x < MH_AXIS_MIN(axis))
    return 0;
  else if (x > MH_AXIS_MAX(axis))
    return imax+1;

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

