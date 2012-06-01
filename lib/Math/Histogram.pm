package Math::Histogram;
use 5.008001;
use strict;
use warnings;
use Carp qw(croak);

our $VERSION = '1.00';

require XSLoader;
XSLoader::load('Math::Histogram', $VERSION);

require Math::Histogram::Axis;

require Exporter;
our @ISA = qw(Exporter);
our @EXPORT_OK = qw(
  make_histogram
);

our %EXPORT_TAGS = (
  'all' => \@EXPORT_OK,
);

sub make_histogram {
  my @axises = map Math::Histogram::Axis->new(@$_), @_;
  return Math::Histogram->new(\@axises);
}


1;
__END__

=head1 NAME

Math::Histogram - N-dimensional histogramming library

=head1 SYNOPSIS

  use Math::Histogram;

=head1 DESCRIPTION

This Perl module wraps an n-dimensional histogramming library
written in C. If all you are looking for is a regular one dimensional
histogram, then consider other libraries such as L<Math::SimpleHisto::XS>
first for simplicity and performance. Some care has been
taken to optimize the library for performance given a variable number
of dimensions, but not knowing the number of dimensions statically
makes for both somewhat inefficient algorithmic implementation as well as
occasionally awkward APIs. For example, simply iterating through all
bins of a 2D histogram -- a matrix -- is as simple as

  # Pseudo-code
  foreach my $ix (0..$nx-1) {
    foreach my $iy (0..$ny-1) {
      my $z = $matrix->get_bin_content([$ix, $iy]);
    }
  }

If you don't know the number of dimensions statically, you need to do something
like this (there are other ways to do it, too):

  # Pseudo-code
  my $coords = [(0) x $ndims];
  foreach my $i (0..$unrolled_total_nbins-1) {
    my $z = $ndimhisto->get_bin_content($coords);

    my $i = 0;
    ++$coords->[$i];
    while ($i < $ndims
           && $coords->[$i] >= $ndimhisto->get_axis($i)->nbins)
    {
      $coords->[$i] = 0;
      ++$coords->[++$i];
    }
  }

Not pretty, eh? Not fast either. So keep that in mind: Your application knows
the number of dimensions, the histogramming library does not.

=head1 SEE ALSO

L<Math::SimpleHisto::XS> is a fast 1D histogramming module.

L<SOOT> is a dynamic wrapper around the ROOT C++ library
which does histogramming and much more. Beware, it is experimental
software.

=head1 AUTHOR

Steffen Mueller, E<lt>smueller@cpan.orgE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2012 by Steffen Mueller

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.1 or,
at your option, any later version of Perl 5 you may have available.

=cut
