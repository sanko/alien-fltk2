#!/usr/bin/perl
use strict;
use warnings;
BEGIN { chdir '../..' if not -d '_build'; }
use Test::More tests => 3 * 2;
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

#
my $mydir = dirname(rel2abs(__FILE__));
my $tempdir = tempdir('alien_fltk_t0002_XXXX', TMPDIR => 1, CLEANUP => 1);
for my $link (qw[dynamic static]) {
    my $source = catfile($tempdir, sprintf 'hello_world_%s.cxx', $link);
    open(my $FH, '>', $source)
        || BAIL_OUT(
                   sprintf 'Failed to create source file (%s) to compile: %s',
                   $source, $!);
    my ($obj, $exe);
    syswrite($FH, sprintf <<'END', ($verbose ? 'run()' : 0)); close $FH;
#include <fltk/Window.h>
#include <fltk/Widget.h>
#include <fltk/run.h>
using namespace fltk;

int main( ) {
  Window *window = new Window(300, 180);
  window->begin();
  Widget *box = new Widget(20, 40, 260, 100, "Hello, World!");
  box->box(UP_BOX);
  box->labelfont(HELVETICA_BOLD_ITALIC);
  box->labelsize(36);
  box->labeltype(SHADOW_LABEL);
  window->end();
  window->show();
  return %s;
}
END
    $obj = $build->cbuilder->compile(
                               source       => $source,
                               include_dirs => [Alien::FLTK->include_path()],
                               extra_compiler_flags => Alien::FLTK->cxxflags()
    );
    ok($obj, 'Compile with FLTK headers');
    $exe =
        $build->cbuilder->link_executable(
                             objects            => $obj,
                             extra_linker_flags => Alien::FLTK->ldflags($link)
        );
    ok($exe, ucfirst $link . 'ally link exe with fltk');
    ok(!system($exe), sprintf 'Run exe we %sally linked with fltk', $link);
}
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
