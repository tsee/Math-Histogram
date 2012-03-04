#define PERL_NO_GET_CONTEXT
#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"

#include "ppport.h"

#include "perl_type_tools.h"

#include "mh_histogram.h"

#define ASSERT_UPPER_BIN_RANGE(axis, ibin) \
    STMT_START { \
      if (ibin > MH_AXIS_NBINS(axis)+1) { \
        croak("Bin %u outside axis bin range (min: 0, max: %u)", ibin, MH_AXIS_NBINS(axis)+1); \
      } \
    } STMT_END

#define ASSERT_BIN_RANGE(axis, ibin) \
    STMT_START { \
      if (ibin < 0 || ibin > MH_AXIS_NBINS(axis)+1) { \
        croak("Bin %u outside axis bin range (min: 0, max: %u)", ibin, MH_AXIS_NBINS(axis)+1); \
      } \
    } STMT_END

MODULE = Math::Histogram    PACKAGE = Math::Histogram

REQUIRE: 2.21

MODULE = Math::Histogram    PACKAGE = Math::Histogram::Axis

mh_axis_t *
mh_axis_t::new(...)
  PREINIT:
    SV *tmp;
    AV *bins;
    I32 n;
  CODE:
    /* varbins => just a single arrayref */
    if (items == 2) {
      tmp = ST(1);
      DEREF_RV_TO_AV(bins, tmp);
      if (bins == NULL)
        croak("Need either array reference as first parameter or a number of bins followed by min/max");
      n = av_len(bins) + 1;
      if (n <= 1)
        croak("Bins array must have at least on bin lower and upper boundary");

      RETVAL = mh_axis_create( n, MH_AXIS_OPT_VARBINS );
      if (RETVAL == NULL)
        croak("Cannot create Math::Histogram::Axis! Invalid bin number or out of memory.");

      av_to_double_ary(aTHX_ bins, RETVAL->bins);
      mh_axis_init( RETVAL, RETVAL->bins[0], RETVAL->bins[n] );
    }
    /* fixbins => n, min, max */
    else if (items == 4) {
      RETVAL = mh_axis_create( SvUV(ST(1)), MH_AXIS_OPT_FIXEDBINS );
      if (RETVAL == NULL)
        croak("Cannot create Math::Histogram::Axis! Invalid bin number or out of memory.");
      mh_axis_init( RETVAL, SvNV(ST(2)), SvNV(ST(3)) );
    }
  OUTPUT: RETVAL


void
mh_axis_t::DESTROY()
  CODE:
    mh_axis_free(THIS);


mh_axis_t *
mh_axis_t::clone()
  PREINIT:
    const char *CLASS = "Math::Histogram::Axis"; /* hack around deficient typemap */
  CODE:
    RETVAL = mh_axis_clone(THIS);
  OUTPUT: RETVAL


unsigned int
mh_axis_t::nbins()
  CODE:
    RETVAL = MH_AXIS_NBINS(THIS);
  OUTPUT: RETVAL


double
mh_axis_t::min()
  CODE:
    RETVAL = MH_AXIS_MIN(THIS);
  OUTPUT: RETVAL


double
mh_axis_t::max()
  CODE:
    RETVAL = MH_AXIS_MAX(THIS);
  OUTPUT: RETVAL


double
mh_axis_t::width()
  CODE:
    RETVAL = MH_AXIS_WIDTH(THIS);
  OUTPUT: RETVAL



double
mh_axis_t::binsize(unsigned int ibin = 0)
  CODE:
    ASSERT_UPPER_BIN_RANGE(THIS, ibin);
    RETVAL = MH_AXIS_BINSIZE(THIS, ibin);
  OUTPUT: RETVAL


double
mh_axis_t::lower_boundary(unsigned int ibin = 0)
  CODE:
    ASSERT_UPPER_BIN_RANGE(THIS, ibin);
    RETVAL = MH_AXIS_BIN_LOWER(THIS, ibin);
  OUTPUT: RETVAL


double
mh_axis_t::upper_boundary(unsigned int ibin = 0)
  CODE:
    ASSERT_UPPER_BIN_RANGE(THIS, ibin);
    RETVAL = MH_AXIS_BIN_UPPER(THIS, ibin);
  OUTPUT: RETVAL


double
mh_axis_t::bin_center(unsigned int ibin = 0)
  CODE:
    ASSERT_UPPER_BIN_RANGE(THIS, ibin);
    RETVAL = MH_AXIS_BIN_CENTER(THIS, ibin);
  OUTPUT: RETVAL


unsigned int
mh_axis_t::find_bin(double x)
  CODE:
    RETVAL = mh_axis_find_bin(THIS, x);
  OUTPUT: RETVAL




MODULE = Math::Histogram    PACKAGE = Math::Histogram


mh_histogram_t *
mh_histogram_t::new(...)
  CODE:
    RETVAL = mh_hist_create(0, NULL);
  OUTPUT: RETVAL


void
mh_histogram_t::DESTROY()
  CODE:
    mh_hist_free(THIS);

