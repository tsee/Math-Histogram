use strict;
use warnings;
use Test::More;
use Config qw(%Config);
use File::Spec;
use Capture::Tiny qw(capture);

#FIXME similar (trivial) logic in Makefile.PL...
my $ctest_dir;
if (-d 't') {
  $ctest_dir = 'ctest';
}
else {
  $ctest_dir = File::Spec->catdir(File::Spec->updir, 'ctest');
}

pass();

my @ctests = glob( "$ctest_dir/*.c" );
my @exe = grep -f $_, map {s/\.c$/$Config{exe_ext}/; $_} @ctests;

foreach my $executable (@exe) {
  subtest "Testing in C: $executable" => sub {
    my ($stdout, $stderr) = capture {
      system($executable)
        and fail("C test did not exit with 0");
    };
    $stdout =~ s/^/    /mg;
    Test::More->builder->use_numbers(0);
    pass();
    Test::More->builder->use_numbers(1);
    done_testing(0) if not $stdout =~ s/^(\s*1\.\.)(\d+)(\s*)$/$1 . ($2 ? $2+1 : 0) . $3/me;
    print $stdout;
    warn $stderr if defined $stderr and $stderr ne '';
  };
}

done_testing();

