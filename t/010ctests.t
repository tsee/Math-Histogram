use strict;
use warnings;
use Test::More;
use Config qw(%Config);
use File::Spec;
use Capture::Tiny qw(capture);

#FIXME similar (trivial) logic in Makefile.PL...
my ($USE_VALGRIND, $USE_GDB);
my $in_testdir = not(-d 't');
my $base_dir;
my $ctest_dir;
if ($in_testdir) {
  $base_dir = File::Spec->updir;
  $USE_VALGRIND = -e File::Spec->catfile(File::Spec->updir, 'USE_VALGRIND');
  $USE_GDB = -e File::Spec->catfile(File::Spec->updir, 'USE_GDB');
}
else {
  $base_dir = File::Spec->curdir;
  $USE_VALGRIND = -e 'USE_VALGRIND';
  $USE_GDB = -e 'USE_GDB';
}
$ctest_dir = File::Spec->catdir($base_dir, 'ctest');

pass();

my @ctests = glob( "$ctest_dir/*.c" );
my @exe = grep -f $_, map {s/\.c$/$Config{exe_ext}/; $_} @ctests;

foreach my $executable (@exe) {
  subtest "Testing in C: $executable" => sub {
    my ($stdout, $stderr) = capture {
      my @cmd;
      if ($USE_VALGRIND) {
        push @cmd, "valgrind", "--suppressions=" .  File::Spec->catfile($base_dir, 'perl.supp');
      }
      elsif ($USE_GDB) {
        push @cmd, "gdb";
      }
      push @cmd, $executable;
      note("@cmd");
      system(@cmd)
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

