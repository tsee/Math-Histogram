#define PERL_NO_GET_CONTEXT
#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"

#include "ppport.h"

/* #include "mh_histogram.h" */
#include "mh_axis.h"

MODULE = Math::Histogram    PACKAGE = Math::Histogram

REQUIRE: 3.11

TYPEMAP: <<HERE
# from "perlobject.map"  Dean Roehrich, version 19960302
# O_OBJECT      -> link an opaque C or C++ object to a blessed Perl object.

TYPEMAP
mh_histogram *        O_OBJECT

OUTPUT

# The Perl object is blessed into 'CLASS', which should be a
# char* having the name of the package for the blessing.
O_OBJECT
        sv_setref_pv( $arg, CLASS, (void*)$var );

######################################################################
INPUT

O_OBJECT
        if( sv_isobject($arg) && (SvTYPE(SvRV($arg)) == SVt_PVMG) )
                $var = ($type)SvIV((SV*)SvRV( $arg ));
        else{
                warn( \"${Package}::$func_name() -- $var is not a blessed SV reference\" );
                XSRETURN_UNDEF;
        }
HERE


##void
##DESTROY(self)
##    simple_histo_1d* self
##  CODE:
##    HS_DEALLOCATE(self);

