#define PERL_NO_GET_CONTEXT
#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"

#include "ppport.h"

#include "perl_type_tools.h"

#include "mh_histogram.h"

#define ASSERT_BIN_RANGE(axis, ibin) \
    STMT_START { \
      if (ibin < 1 || ibin > MH_AXIS_NBINS(axis)) \
        croak("Bin %u outside axis bin range (min: 1, max: %u)", MH_AXIS_NBINS(axis)); \
    } STMT_END

#define ASSERT_BIN_RANGE_WITH_OVERFLOW(axis, ibin) \
    STMT_START { \
      if (ibin < 0 || ibin > MH_AXIS_NBINS(axis)+1) \
        croak("Bin %u outside axis bin range (incl. under- and overflow: min: 0, max: %u)", MH_AXIS_NBINS(axis)+1); \
    } STMT_END


/* The following are flags that we use on the userdata slot of an axis.
 * Right now, that's just using the first bit (take care not to use more than 32...)
 * indicating that if set, the axis is owned by a histogram. If that's the case,
 * using that axis in another histogram will create a clone of the axis.
 * At the same time, any explicit Perl-level reference to the axis will not free
 * the underlying C object if that bit is set as the Perl-level reference goes out of
 * scope. */
#define F_AXIS_OWNED_BY_HIST 1

/*
 * FIXME This file has a bunch of hardcoded class names for non-constructor methods
 *       that return objects. That needs to be fixed!
 */

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

      RETVAL = mh_axis_create( n-1, MH_AXIS_OPT_VARBINS );
      if (RETVAL == NULL)
        croak("Cannot create Math::Histogram::Axis! Invalid bin number or out of memory.");

      av_to_double_ary(aTHX_ bins, RETVAL->bins);
      mh_axis_init( RETVAL, RETVAL->bins[0], RETVAL->bins[n-1] );
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
    /* free only if not owned by some histogram */
    if (!( PTR2UV(MH_AXIS_USERDATA(THIS)) & F_AXIS_OWNED_BY_HIST ))
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
mh_axis_t::binsize(unsigned int ibin = 1)
  CODE:
    ASSERT_BIN_RANGE(THIS, ibin);
    RETVAL = MH_AXIS_BINSIZE(THIS, ibin);
  OUTPUT: RETVAL


double
mh_axis_t::lower_boundary(unsigned int ibin = 1)
  CODE:
    ASSERT_BIN_RANGE(THIS, ibin);
    RETVAL = MH_AXIS_BIN_LOWER(THIS, ibin);
  OUTPUT: RETVAL


double
mh_axis_t::upper_boundary(unsigned int ibin = 1)
  CODE:
    ASSERT_BIN_RANGE(THIS, ibin);
    RETVAL = MH_AXIS_BIN_UPPER(THIS, ibin);
  OUTPUT: RETVAL


double
mh_axis_t::bin_center(unsigned int ibin = 1)
  CODE:
    ASSERT_BIN_RANGE(THIS, ibin);
    RETVAL = MH_AXIS_BIN_CENTER(THIS, ibin);
  OUTPUT: RETVAL


unsigned int
mh_axis_t::find_bin(double x)
  CODE:
    RETVAL = mh_axis_find_bin(THIS, x);
  OUTPUT: RETVAL




MODULE = Math::Histogram    PACKAGE = Math::Histogram


mh_histogram_t *
mh_histogram_t::new(AV *axises)
  PREINIT:
    mh_axis_t **axis_structs;
    mh_axis_t *tmp_axis;
    unsigned int i, n;
  CODE:
    n = av_len(axises)+1;
    if (n == 0)
      croak("Need array reference of axis objetcs");
    axis_structs = av_to_axis_ary(aTHX_ axises, n);
    if (axis_structs == NULL)
      croak("Need array reference of axis objetcs");

    for (i = 0; i < n; ++i) {
      tmp_axis = axis_structs[i];
      /* Clone axis if owned by histogram, otherwise set the "ownership" bit */
      if (PTR2UV(MH_AXIS_USERDATA(tmp_axis)) & F_AXIS_OWNED_BY_HIST)
        axis_structs[i] = mh_axis_clone(tmp_axis);
      else {
        UV flags = PTR2UV(MH_AXIS_USERDATA(tmp_axis));
        flags |= F_AXIS_OWNED_BY_HIST;
        MH_AXIS_USERDATA(tmp_axis) = INT2PTR(void *, flags);
      }
    }

    RETVAL = mh_hist_create(n, axis_structs);
  OUTPUT: RETVAL


void
mh_histogram_t::DESTROY()
  CODE:
    mh_hist_free(THIS);


mh_histogram_t *
mh_histogram_t::clone()
  PREINIT:
    const char *CLASS = "Math::Histogram";
  CODE:
    RETVAL = mh_hist_clone(THIS, 1); /* 1 => do clone data */
  OUTPUT: RETVAL


mh_histogram_t *
mh_histogram_t::new_alike()
  PREINIT:
    const char *CLASS = "Math::Histogram";
  CODE:
    RETVAL = mh_hist_clone(THIS, 0); /* 0 => do NOT clone data */
  OUTPUT: RETVAL


mh_axis_t *
mh_histogram_t::get_axis(unsigned int dimension)
  PREINIT:
    const char *CLASS = "Math::Histogram::Axis";
  CODE:
    RETVAL = MH_HIST_AXIS(THIS, dimension);
  OUTPUT: RETVAL


unsigned int
mh_histogram_t::ndim()
  CODE:
    RETVAL = MH_HIST_NDIM(THIS);
  OUTPUT: RETVAL


unsigned int
mh_histogram_t::nfills()
  CODE:
    RETVAL = MH_HIST_NFILLS(THIS);
  OUTPUT: RETVAL


double
mh_histogram_t::total()
  CODE:
    RETVAL = MH_HIST_TOTAL(THIS);
  OUTPUT: RETVAL


AV *
mh_histogram_t::find_bin_numbers(coords)
    AV *coords;
  CODE:
    av_to_double_ary(aTHX_ coords, MH_HIST_ARG_COORD_BUFFER(THIS));
    mh_hist_find_bin_numbers(THIS, MH_HIST_ARG_COORD_BUFFER(THIS), MH_HIST_ARG_BIN_BUFFER(THIS));
    unsigned_int_ary_to_av(aTHX_ MH_HIST_NDIM(THIS), MH_HIST_ARG_BIN_BUFFER(THIS), &RETVAL);
    sv_2mortal((SV*)RETVAL);
  OUTPUT: RETVAL


void
mh_histogram_t::fill(coords)
    AV *coords;
  CODE:
    av_to_double_ary(aTHX_ coords, MH_HIST_ARG_COORD_BUFFER(THIS));
    mh_hist_fill(THIS, MH_HIST_ARG_COORD_BUFFER(THIS));


void
mh_histogram_t::fill_w(coords, weight)
    AV *coords;
    double weight;
  CODE:
    av_to_double_ary(aTHX_ coords, MH_HIST_ARG_COORD_BUFFER(THIS));
    mh_hist_fill_w(THIS, MH_HIST_ARG_COORD_BUFFER(THIS), weight);


void
mh_histogram_t::fill_n(coords)
    AV *coords;
  PREINIT:
    SV **elem;
    SV *sv;
    unsigned int i, n;
  CODE:
    n = av_len(coords)+1;
    /* Fill each individually since we have
     * to do lots of Perl => C conversion anyway */
    for (i = 0; i < n; ++i) {
      elem = av_fetch(coords, i, 0);
      if (elem == NULL)
        croak("Woah, this should never happen!");

      /* Inner array deref */
      sv = *elem;
      SvGETMAGIC(sv);
      if (SvROK(sv) && SvTYPE(SvRV(sv)) == SVt_PVAV) {
        av_to_double_ary(aTHX_ (AV*)SvRV(sv), MH_HIST_ARG_COORD_BUFFER(THIS));
        mh_hist_fill(THIS, MH_HIST_ARG_COORD_BUFFER(THIS));
      }
      else
        croak("Element with index %u of input array reference is "
              "not an array reference, stopping histogram filling "
              "at that point!", i);
    }


void
mh_histogram_t::fill_nw(coords, weights)
    AV *coords;
    AV *weights;
  PREINIT:
    SV **elem;
    SV *sv;
    unsigned int i, n;
    double weight;
  CODE:
    n = av_len(coords)+1;
    if ((unsigned int)(av_len(weights)+1) != n)
      croak("Coordinates and weights arrays need to be of same size!");

    /* Fill each individually since we have
     * to do lots of Perl => C conversion anyway */
    for (i = 0; i < n; ++i) {
      elem = av_fetch(weights, i, 0);
      if (elem == NULL)
        croak("Woah, this should never happen!");
      weight = SvNV(*elem);

      elem = av_fetch(coords, i, 0);
      if (elem == NULL)
        croak("Woah, this should never happen!");

      /* Inner array deref */
      sv = *elem;
      SvGETMAGIC(sv);
      if (SvROK(sv) && SvTYPE(SvRV(sv)) == SVt_PVAV) {
        av_to_double_ary(aTHX_ (AV*)SvRV(sv), MH_HIST_ARG_COORD_BUFFER(THIS));
        mh_hist_fill_w(THIS, MH_HIST_ARG_COORD_BUFFER(THIS), weight);
      }
      else
        croak("Element with index %u of input array reference is "
              "not an array reference, stopping histogram filling "
              "at that point!", i);
    }

