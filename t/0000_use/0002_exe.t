#!/usr/bin/perl
use strict;
use warnings;
use Test::More tests => 3;
use Config qw[%Config];
use File::Temp qw[tempfile];
use Time::HiRes qw[];
use Module::Build;
$|++;
my $test_builder = Test::More->builder;
chdir '../..' if not -d '_build';
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
use Alien::FLTK;
my ($FH, $source)
    = tempfile('alien_fltk_t001_XXXX', SUFFIX => '.cxx', DIR => './');
my ($obj, $exe);

END {
    for (grep defined, $obj, $exe, $source) { 1 while unlink; }
}
syswrite($FH, sprintf <<'END', ($verbose ? 'run()' : 0)); close $FH;
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
  window->end();
  window->show(argc, argv);
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
          objects => [$obj],
          extra_linker_flags =>
              [Alien::FLTK->ldflags(), '-L"' . Alien::FLTK->library_path() . '"']
    );
ok($exe,          'Link exe with fltk');
ok(!system($exe), 'Run exe with fltk');
