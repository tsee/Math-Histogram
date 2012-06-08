package Math::Histogram::Axis;
use strict;
use warnings;
use Math::Histogram ();

1;

__END__

=head1 NAME

Math::Histogram::Axis - Object representing single histogram dimension

=head1 SYNOPSIS

  use Math::Histogram;
  # 10 bins between 0 and 1
  my $fixed_bin = Math::Histogram::Axis->new(10, 0., 1.);
  # 5 bins of variable size
  my $var_bin = Math::Histogram::Axis->new([1, 2, 4, 8, 16]);
  
=head1 DESCRIPTION


=head1 SEE ALSO

L<Math::Histogram>

=head1 AUTHOR

Steffen Mueller, E<lt>smueller@cpan.orgE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2012 by Steffen Mueller

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.1 or,
at your option, any later version of Perl 5 you may have available.

=cut
