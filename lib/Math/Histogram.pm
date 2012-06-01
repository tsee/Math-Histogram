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
first for simplicity and performance. This being said, some care has been
taken to optimize the library for performance given a variable number
of dimensions.

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
