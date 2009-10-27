use strict;
use warnings;
BEGIN { chdir '../..' if not -d '_build'; }
use Test::More tests => 3;
use File::Temp;
use lib qw[blib/lib];
use Alien::FLTK;
use ExtUtils::CBuilder;
$|++;
my $CC = ExtUtils::CBuilder->new(quiet => 1);
my $AF = Alien::FLTK->new();
my ($FH, $SRC)
    = File::Temp->tempfile('alien_fltk_t0002_XXXX',
                           TMPDIR  => 1,
                           UNLINK  => 1,
                           SUFFIX  => '.cxx',
                           CLEANUP => 1
    );
syswrite($FH, <<'END') || BAIL_OUT("Failed to write to $SRC: $!"); close $FH;
#include <fltk/Window.h>
#include <fltk/Widget.h>
#include <fltk/run.h>
using namespace fltk;

int main(int argc, char **argv) {
  Window *window = new Window(300, 180);
  window->begin();
  Widget *box = new Widget(20, 40, 260, 100, "Hello, World!");
  box->box(UP_BOX);
  box->labelfont(HELVETICA_BOLD_ITALIC);
  box->labelsize(36);
  box->labeltype(SHADOW_LABEL);
  window->end();            /* Showing the window causes the test to fail on
  window->show(argc, argv);    X11 w/o a display. Testing the creation of the
  wait(0.1);                   window and a widget should be enough.
  window->hide();           */
  return 0;
}
END
my $OBJ = $CC->compile('C++'                => 1,
                       source               => $SRC,
                       include_dirs         => [$AF->include_dirs()],
                       extra_compiler_flags => $AF->cxxflags()
);
ok($OBJ, 'Compile with FLTK headers');
my $EXE =
    $CC->link_executable(objects            => $OBJ,
                         extra_linker_flags => $AF->ldflags());
ok($EXE,          'Link exe with fltk');
ok(!system($EXE), sprintf 'Run exe');
unlink $OBJ, $EXE, $SRC;

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
