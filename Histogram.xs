#define PERL_NO_GET_CONTEXT
#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"

#include "assert.h"
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

static SV *
axis_to_hashref(pTHX_ mh_axis_t *axis)
{
  SV *rv;
  HV *hash;
  hash = newHV();

  if (MH_AXIS_ISFIXBIN(axis)) {
    assert( hv_stores(hash, "nbins", newSVuv(MH_AXIS_NBINS(axis))) );
    assert( hv_stores(hash, "min", newSVnv(MH_AXIS_MIN(axis))) );
    assert( hv_stores(hash, "max", newSVnv(MH_AXIS_MAX(axis))) );
  }
  else {
    unsigned int i, n;
    AV *bin_av;
    double *bins = axis->bins;
    n = MH_AXIS_NBINS(axis);
    bin_av = newAV();
    assert( hv_stores(hash, "bins", newRV_noinc((SV *)bin_av)) );
    av_extend(bin_av, n);
    for (i = 0; i <= n; ++i)
      av_store(bin_av, i, newSVnv(bins[i]));
  }
  rv = newRV_noinc((SV *)hash);

  return rv;
}

static mh_axis_t *
hash_to_axis(pTHX_ HV *hash)
{
  unsigned int nbins;
  SV *tmp;
  SV **svptr;
  mh_axis_t *rv;

  if (hv_exists(hash, "bins", 4)) { /* varbins */
    AV *bin_av;
    tmp = *hv_fetchs(hash, "bins", 0);
    DEREF_RV_TO_AV(bin_av, tmp);
    if (bin_av == NULL)
      croak("'bins' entry is not an array reference");
    nbins = av_len(bin_av);
    rv = mh_axis_create( nbins, MH_AXIS_OPT_VARBINS );
    if (rv == NULL)
      croak("Cannot create Math::Histogram::Axis! Invalid number of bins or out of memory.");
    av_to_double_ary(aTHX_ bin_av, rv->bins);
    /* FIXME include same bin order sanity check as for the normal constructor? */
    mh_axis_init( rv, rv->bins[0], rv->bins[nbins] );
  }
  else { /* fixed width bins */
    double min, max;
    svptr = hv_fetchs(hash, "nbins", 0);
    if (svptr == NULL)
      croak("Missing 'bins' and 'nbins' hash entries");
    nbins = SvUV(*svptr);
    svptr = hv_fetchs(hash, "min", 0);
    if (svptr == NULL)
      croak("Missing 'min' hash entry");
    min = SvNV(*svptr);
    svptr = hv_fetchs(hash, "max", 0);
    if (svptr == NULL)
      croak("Missing 'max' hash entry");
    max = SvNV(*svptr);
    if (min > max) {
      double tmp = min;
      min = max;
      max = tmp;
    }
    rv = mh_axis_create( nbins, MH_AXIS_OPT_FIXEDBINS );
    if (rv == NULL)
      croak("Cannot create Math::Histogram::Axis! Invalid bin number or out of memory.");
    mh_axis_init( rv, min, max );
  }

  return rv;
}

/*
 * FIXME This file has a bunch of hardcoded class names for non-constructor methods
 *       that return objects. That needs to be fixed!
 */

MODULE = Math::Histogram    PACKAGE = Math::Histogram

PROTOTYPES: DISABLE

REQUIRE: 2.21

MODULE = Math::Histogram    PACKAGE = Math::Histogram::Axis

mh_axis_t *
mh_axis_t::new(...)
  PREINIT:
    SV *tmp;
    AV *bins;
    I32 n, i;
    double prev;
    double *dbl_ary;
  CODE:
    /* varbins => just a single arrayref */
    if (items == 2) {
      tmp = ST(1);
      DEREF_RV_TO_AV(bins, tmp);
      if (bins == NULL)
        croak("Need either array reference as first parameter or a number of bins followed by min/max");
      n = av_len(bins) + 1;
      if (n <= 1)
        croak("Bins array must have at least a lower and upper boundary for a single bin");

      RETVAL = mh_axis_create( n-1, MH_AXIS_OPT_VARBINS );
      if (RETVAL == NULL)
        croak("Cannot create Math::Histogram::Axis! Invalid number of bins or out of memory.");

      av_to_double_ary(aTHX_ bins, RETVAL->bins);

      /* Check whether the numbers make some basic sense */
      dbl_ary = RETVAL->bins;
      prev = dbl_ary[0];
      for (i = 1; i < n; ++i) {
        if (dbl_ary[i] <= prev) {
          mh_axis_free(RETVAL);
          croak("Bin boundaries for histogram axis are not strictly monotonic!");
        }
        prev = dbl_ary[i];
      }
      mh_axis_init( RETVAL, RETVAL->bins[0], RETVAL->bins[n-1] );
    }
    /* fixbins => n, min, max */
    else if (items == 4) {
      RETVAL = mh_axis_create( SvUV(ST(1)), MH_AXIS_OPT_FIXEDBINS );
      if (RETVAL == NULL)
        croak("Cannot create Math::Histogram::Axis! Invalid number of bins or out of memory.");
      prev = SvNV(ST(2));
      if (prev >= SvNV(ST(3))) {
        mh_axis_free(RETVAL);
        croak("Lower axis boundary (%f) cannot be larger than or equal to upper boundary (%f)!", prev, SvNV(ST(3)));
      }
      mh_axis_init( RETVAL, prev, SvNV(ST(3)) );
    }
  OUTPUT: RETVAL


void
mh_axis_t::DESTROY()
  CODE:
    /* free only if not owned by some histogram */
    if (!( PTR2UV(MH_AXIS_USERDATA(THIS)) & F_AXIS_OWNED_BY_HIST ))
      mh_axis_free(THIS);


void
mh_axis_t::_as_hash()
  PREINIT:
    SV *rv;
  PPCODE:
    rv = sv_2mortal(axis_to_hashref(aTHX_ THIS));
    XPUSHs(rv);
    XSRETURN(1);


mh_axis_t *
_from_hash(CLASS, hash)
    char *CLASS;
    HV *hash;
  CODE:
    RETVAL = hash_to_axis(aTHX_ hash);
  OUTPUT: RETVAL


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
    if (dimension >= MH_HIST_NDIM(THIS))
      croak("Dimension number out of bounds: %u", dimension);
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


void
mh_histogram_t::fill_bin(dim_bin_nums)
    AV *dim_bin_nums;
  CODE:
    av_to_unsigned_int_ary(aTHX_ dim_bin_nums, MH_HIST_ARG_BIN_BUFFER(THIS));
    mh_hist_fill_bin(THIS, MH_HIST_ARG_BIN_BUFFER(THIS));


void
mh_histogram_t::fill_bin_w(dim_bin_nums, weight)
    AV *dim_bin_nums;
    double weight;
  CODE:
    av_to_unsigned_int_ary(aTHX_ dim_bin_nums, MH_HIST_ARG_BIN_BUFFER(THIS));
    mh_hist_fill_bin_w(THIS, MH_HIST_ARG_BIN_BUFFER(THIS), weight);


void
mh_histogram_t::fill_bin_n(dim_bin_nums)
    AV *dim_bin_nums;
  PREINIT:
    SV **elem;
    SV *sv;
    unsigned int i, n;
  CODE:
    n = av_len(dim_bin_nums)+1;
    /* Fill each individually since we have
     * to do lots of Perl => C conversion anyway */
    for (i = 0; i < n; ++i) {
      elem = av_fetch(dim_bin_nums, i, 0);
      if (elem == NULL)
        croak("Woah, this should never happen!");

      /* Inner array deref */
      sv = *elem;
      SvGETMAGIC(sv);
      if (SvROK(sv) && SvTYPE(SvRV(sv)) == SVt_PVAV) {
        av_to_unsigned_int_ary(aTHX_ (AV*)SvRV(sv), MH_HIST_ARG_BIN_BUFFER(THIS));
        mh_hist_fill_bin(THIS, MH_HIST_ARG_BIN_BUFFER(THIS));
      }
      else
        croak("Element with index %u of input array reference is "
              "not an array reference, stopping histogram filling "
              "at that point!", i);
    }


void
mh_histogram_t::fill_bin_nw(dim_bin_nums, weights)
    AV *dim_bin_nums;
    AV *weights;
  PREINIT:
    SV **elem;
    SV *sv;
    unsigned int i, n;
    double weight;
  CODE:
    n = av_len(dim_bin_nums)+1;
    if ((unsigned int)(av_len(weights)+1) != n)
      croak("Bin-numbers and weights arrays need to be of same size!");

    /* Fill each individually since we have
     * to do lots of Perl => C conversion anyway */
    for (i = 0; i < n; ++i) {
      elem = av_fetch(weights, i, 0);
      if (elem == NULL)
        croak("Woah, this should never happen!");
      weight = SvNV(*elem);

      elem = av_fetch(dim_bin_nums, i, 0);
      if (elem == NULL)
        croak("Woah, this should never happen!");

      /* Inner array deref */
      sv = *elem;
      SvGETMAGIC(sv);
      if (SvROK(sv) && SvTYPE(SvRV(sv)) == SVt_PVAV) {
        av_to_unsigned_int_ary(aTHX_ (AV*)SvRV(sv), MH_HIST_ARG_BIN_BUFFER(THIS));
        mh_hist_fill_bin_w(THIS, MH_HIST_ARG_BIN_BUFFER(THIS), weight);
      }
      else
        croak("Element with index %u of input array reference is "
              "not an array reference, stopping histogram filling "
              "at that point!", i);
    }


double
mh_histogram_t::get_bin_content(dim_bin_nums)
    AV *dim_bin_nums;
  PREINIT:
    int rc;
  CODE:
    av_to_unsigned_int_ary(aTHX_ dim_bin_nums, MH_HIST_ARG_BIN_BUFFER(THIS));
    rc = mh_hist_get_bin_content(THIS, MH_HIST_ARG_BIN_BUFFER(THIS), &RETVAL);
    if (rc != 0)
      croak("Bin numbers out of range!");
  OUTPUT: RETVAL


void
mh_histogram_t::set_bin_content(dim_bin_nums, content)
    AV *dim_bin_nums;
    double content;
  PREINIT:
    int rc;
  CODE:
    av_to_unsigned_int_ary(aTHX_ dim_bin_nums, MH_HIST_ARG_BIN_BUFFER(THIS));
    rc = mh_hist_set_bin_content(THIS, MH_HIST_ARG_BIN_BUFFER(THIS), content);
    if (rc != 0)
      croak("Bin numbers out of range!");


mh_histogram_t *
mh_histogram_t::contract_dimension(contracted_dimension)
    unsigned int contracted_dimension;
  PREINIT:
    const char *CLASS = "Math::Histogram"; /* FIXME */
  CODE:
    RETVAL = mh_hist_contract_dimension(THIS, contracted_dimension);
    if (RETVAL == NULL)
      croak("Contracted dimension appears to be out of range!");
  OUTPUT: RETVAL


void
mh_histogram_t::cumulate(cumulation_dimension)
    unsigned int cumulation_dimension;
  PREINIT:
    int rc;
  CODE:
    rc = mh_hist_cumulate(THIS, cumulation_dimension);
    if (rc != 0)
      croak("Cumulated dimension appears to be out of range!");

int
mh_histogram_t::data_equal_to(other)
    mh_histogram_t *other;
  CODE:
    RETVAL = mh_hist_data_equal(THIS, other);
  OUTPUT: RETVAL


int
mh_histogram_t::is_overflow_bin(dim_bin_nums)
    AV *dim_bin_nums;
  CODE:
    av_to_unsigned_int_ary(aTHX_ dim_bin_nums, MH_HIST_ARG_BIN_BUFFER(THIS));
    RETVAL = !!mh_hist_is_overflow_bin(THIS, MH_HIST_ARG_BIN_BUFFER(THIS));
  OUTPUT: RETVAL

int
mh_histogram_t::is_overflow_bin_linear(linear_bin_num)
    unsigned int linear_bin_num;
  CODE:
    RETVAL = !!mh_hist_is_overflow_bin_linear(THIS, linear_bin_num);
  OUTPUT: RETVAL

void
mh_histogram_t::_debug_bin_iter_print()
  CODE:
    mh_hist_debug_bin_iter_print(THIS);

void
mh_histogram_t::_debug_dump_data()
  CODE:
    mh_hist_debug_dump_data(THIS);

void
mh_histogram_t::_as_hash()
  PREINIT:
    SV *rv;
    SV *tmp;
    HV *hash;
    AV *axis_av;
    AV *data_av;
    unsigned int ndim, i, nbins_total;
    double *data;
  PPCODE:
    hash = newHV();
    rv = sv_2mortal(newRV_noinc((SV *)hash));

    ndim = MH_HIST_NDIM(THIS);
    assert( hv_stores(hash, "ndim", newSVuv(ndim)) );

    /* store axises */
    axis_av = newAV();
    assert( hv_stores(hash, "axises", newRV_noinc((SV *)axis_av)) );
    av_extend(axis_av, ndim-1);
    for (i = 0; i < ndim; ++i) {
      tmp = axis_to_hashref(aTHX_ MH_HIST_AXIS(THIS, i));
      av_store(axis_av, i, tmp);
    }

    assert( hv_stores(hash, "nfills", newSVuv(MH_HIST_NFILLS(THIS))) );
    assert( hv_stores(hash, "total", newSVnv(MH_HIST_TOTAL(THIS))) );

    /* store data */
    /* FIXME: strictly speaking, this violates encapsulation */
    nbins_total = THIS->nbins_total;
    data_av = newAV();
    assert( hv_stores(hash, "data", newRV_noinc((SV *)data_av)) );
    av_extend(data_av, nbins_total-1);
    data = THIS->data;
    for (i = 0; i < nbins_total; ++i)
      av_store(data_av, i, newSVnv(data[i]));

    XPUSHs(rv);
    XSRETURN(1);


mh_histogram_t *
_from_hash_internal(CLASS, hash)
    char *CLASS;
    HV *hash;
  PREINIT:
    mh_axis_t **axis_structs;
    unsigned int i, n, ndim, nfill;
    double total_content;
    double *data;
    SV **svptr;
    AV *axis_av;
    AV *data_av;
  CODE:
    /* dimensionality */
    HV_FETCHS_FATAL(svptr, hash, "ndim");
    ndim = SvUV( *svptr );
    if (ndim < 1)
      croak("Need at least a dimension of 1");

    /* nfills and total */
    HV_FETCHS_FATAL(svptr, hash, "nfills");
    nfill = SvUV( *svptr );
    HV_FETCHS_FATAL(svptr, hash, "total");
    total_content = SvNV( *svptr );

    /* data array */
    HV_FETCHS_FATAL(svptr, hash, "data");
    DEREF_RV_TO_AV(data_av, *svptr);
    if (data_av == NULL)
      croak("'data' entry is not an array reference");

    /* axises */
    HV_FETCHS_FATAL(svptr, hash, "axises");
    DEREF_RV_TO_AV(axis_av, *svptr);
    if (axis_av == NULL)
      croak("'axises' entry is not an array reference");

    n = av_len(axis_av)+1;
    if (n != ndim)
      croak("Number of axises needs to be same as number of dimensions");

    axis_structs = av_to_axis_ary(aTHX_ axis_av, n);
    if (axis_structs == NULL)
      croak("Need array reference of axis objetcs");

    /* make output struct */
    RETVAL = mh_hist_create(ndim, axis_structs);
    RETVAL->nfills = nfill;
    RETVAL->total = total_content;

    /* fill data */
    n = RETVAL->nbins_total;
    if ((unsigned int)(av_len(data_av)+1) != n) {
      free(RETVAL);
      croak("Input data array length (%u) is not the same as the total number of bins in the histogram (%u)", av_len(data_av)+1, n);
    }
    data = RETVAL->data;
    for (i = 0; i < n; ++i) {
      svptr = av_fetch(data_av, i, 0);
      if (svptr == NULL) {
        free(RETVAL);
        croak("Failed to fetch scalar from array!?");
      }
      data[i] = SvNV(*svptr);
    }
  OUTPUT: RETVAL

