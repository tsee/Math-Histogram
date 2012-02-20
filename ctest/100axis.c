#include <stdio.h>
#include <stdlib.h>
#include <mh_axis.h>

#include "mytap.h"

int
main (int argc, char **argv)
{
  mh_axis_t *axis;
  ok(1);
  
  axis = mh_axis_create(10, 0);
  mh_axis_free(axis);

  done_testing();
  return 0;
}


