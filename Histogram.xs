#define PERL_NO_GET_CONTEXT
#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"

#include "ppport.h"

#include "perl_type_tools.h"

#include "mh_histogram.h"

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
    /* varbins => just arrayref */
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

