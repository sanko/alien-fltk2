#!/usr/bin/perl
use strict;
use warnings;
BEGIN { chdir '../..' if not -d '_build'; }
use Test::More tests => 1;
use Config qw[%Config];
use File::Temp qw[tempfile tempdir];
use File::Spec::Functions qw[rel2abs catfile];
use File::Basename qw[dirname];
use Time::HiRes qw[];
use Module::Build qw[];
use lib qw[blib/lib inc];
use Alien::FLTK;
$|++;
my $test_builder    = Test::More->builder;
my $build           = Module::Build->current;
my $release_testing = $build->config_data('release_testing');
my $verbose         = $build->config_data('verbose');
$SIG{__WARN__} = (
    $verbose
    ? sub {
        diag(sprintf(q[%02.4f], Time::HiRes::time- $^T), q[ ], shift);
        }
    : sub { }
);

#
use lib qw[blib/lib inc];
use_ok('Alien::FLTK');
=pod

=head1 Author

Sanko Robinson <sanko@cpan.org> - http://sankorobinson.com/

CPAN ID: SANKO

=head1 License and Legal

Copyright (C) 2009 by Sanko Robinson E<lt>sanko@cpan.orgE<gt>

This program is free software; you can redistribute it and/or modify it under
the terms of The Artistic License 2.0. See the F<LICENSE> file included with
this distribution or http://www.perlfoundation.org/artistic_license_2_0.  For
clarification, see http://www.perlfoundation.org/artistic_2_0_notes.

When separated from the distribution, all POD documentation is covered by the
Creative Commons Attribution-Share Alike 3.0 License. See
http://creativecommons.org/licenses/by-sa/3.0/us/legalcode.  For
clarification, see http://creativecommons.org/licenses/by-sa/3.0/us/.

=for git $Id$

=cut
