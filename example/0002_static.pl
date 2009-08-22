#!perl
use strict;
use warnings;
use Alien::FLTK;
use ExtUtils::CBuilder;
my $CC     = ExtUtils::CBuilder->new();
my $source = 'hello_world.cxx';
open(my $FH, '>', $source) || die '...';
syswrite($FH, <<'') || die '...'; close $FH;
#line 11 "0002_static.pl"
#include <fltk/Window.h>
#include <fltk/Widget.h>
#include <fltk/run.h>
using namespace fltk;
int main(int argc, char **argv, char **env) {
  Window *window = new Window(300, 180);
  window->begin();
  Widget *box = new Widget(20, 40, 260, 100, "Hello, World!");
  box->box(UP_BOX);
  box->labelfont(HELVETICA_BOLD_ITALIC);
  box->labelsize(36);
  box->labeltype(SHADOW_LABEL);
  window->end();
  window->show(argc, argv);
  return run();
}

my $obj = $CC->compile(source               => $source,
                       extra_compiler_flags => Alien::FLTK->cxxflags());
my $exe = $CC->link_executable(
                      objects            => $obj,
                      extra_linker_flags => [Alien::FLTK->ldflags(qw[static])]
);
printf system($exe) ? 'Aww...' : 'Yay! %s bytes', -s $exe;
END { unlink grep defined, $source, $obj, $exe; }
