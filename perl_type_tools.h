#ifndef perl_type_tools_h_
#define perl_type_tools_h_

#define DEREF_RV_TO_AV(av, sv) \
        STMT_START { \
                SvGETMAGIC(sv); \
                if (SvROK(sv) && SvTYPE(SvRV(sv)) == SVt_PVAV) \
                    av = (AV*)SvRV(sv); \
                else \
                  av = NULL; \
        } STMT_END

STATIC void
av_to_double_ary(pTHX_ AV* in, double* out)
{
  I32 thisN;
  SV** elem;
  I32 i;

  thisN = av_len(in)+1;
  if (thisN == 0)
    return;

  for (i = 0; i < thisN; ++i) {
    if (NULL == (elem = av_fetch(in, i, 0))) {
      croak("Could not fetch element from array");
    }
    else
      out[i] = SvNV(*elem);
  }
}



#endif
