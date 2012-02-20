use 5.008001;
use strict;
use warnings;
use ExtUtils::MakeMaker;
use Config qw(%Config);

# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
my $name = 'Math::Histogram';
my $define = '';

my $DEBUG = grep {/--debug/} @ARGV;
if ($DEBUG) {
  $define = '-Wall -Wextra -O0 -ggdb -pedantic -Wno-long-long -finstrument-functions';
}
else {
  $define = '-O2';
}

my @test_cfiles;
my @test_exefiles;
if ($DEBUG) {
  my $ctest_dir = 'ctest';
  @test_cfiles = glob("$ctest_dir/*.c");
  foreach my $file (@test_cfiles) {
    (my $exefile = $file) =~ s/\.c$/$Config{exe_ext}/;
    push @test_exefiles, $exefile;
  }
  print "Debug mode. Will build C tests:\n  ",
    join("\n  ", @test_exefiles), "\n";
}

WriteMakefile(
    NAME              => $name,
    VERSION_FROM      => 'lib/Math/Histogram.pm', # finds $VERSION
    PREREQ_PM         => {
      'ExtUtils::ParseXS' => '2.21',
      'Test::More' => '0.94',
      'File::Spec' => '0',
      'Capture::Tiny' => '0',
    },
    ($] >= 5.005 ?
      (ABSTRACT_FROM  => 'lib/Math/Histogram.pm', # retrieve abstract from module
       AUTHOR         => 'Steffen Mueller <smueller@cpan.org>') : ()),
    LIBS              => [''],
    DEFINE            => $define,
    INC               => '-I.',
    OBJECT            => '$(O_FILES)', # link all the C files too
    clean => {FILES => "@test_exefiles"}
);


sub MY::postamble {
  if ($DEBUG) {
    my $make_frag = <<MAKE_FRAG;
linkext :: ctests

ctests:
MAKE_FRAG
    foreach my $i (0..$#test_cfiles) {
      my $file = $test_cfiles[$i];
      my $exefile = $test_exefiles[$i];
      $make_frag .= "\t\$(CC) $define -I. $file mh*.o -o $exefile\n";
    }
    return $make_frag;
  }
  else {
    return "\n";
  }
}

