use strict;
use warnings;
BEGIN {
  push @INC, 't/lib', 'lib';
}
use Math::Histogram::Test;

run_ctest('100_axis');


