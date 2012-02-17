#define PERL_NO_GET_CONTEXT
#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"

#include "ppport.h"

/* #include "mh_histogram.h" */
#include "mh_axis.h"

MODULE = Math::Histogram    PACKAGE = Math::Histogram

REQUIRE: 2.21

##void
##DESTROY(self)
##    simple_histo_1d* self
##  CODE:
##    HS_DEALLOCATE(self);

