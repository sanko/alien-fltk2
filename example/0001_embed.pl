#!perl
use strict;
use warnings;
use Alien::FLTK;
use ExtUtils::CBuilder;
use Config qw[%Config];
my $CC     = ExtUtils::CBuilder->new();
my $source = 'hello_world.cxx';
open(my $FH, '>', $source) || die '...';
syswrite($FH, <<'') || die '...'; close $FH;
      #include <fltk/Window.h>
      #include <fltk/Widget.h>
      #include <fltk/run.h>
      #include <perl.h>
      #include <EXTERN.h>
      using namespace fltk;
      static PerlInterpreter *my_perl;
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
        PERL_SYS_INIT3(&argc,&argv,&env);
        my_perl = perl_alloc();
        perl_construct(my_perl);
        PL_exit_flags |= PERL_EXIT_DESTRUCT_END;
        Perl_warn(my_perl, "Oh, hai");
        perl_destruct(my_perl);
        perl_free(my_perl);
        PERL_SYS_TERM();
        return run();
      }

my $obj = $CC->compile(source               => $source,
                       include_dirs         => [Alien::FLTK->include_path()],
                       extra_compiler_flags => Alien::FLTK->cxxflags()
);
my $exe = $CC->link_executable(
                      objects            => [$obj],
                      extra_linker_flags => [
                           Alien::FLTK->ldflags(),
                           '-L"' . Alien::FLTK->library_path() . '"',
                           $Config{'archlib'} . '/CORE/' . $Config{'libperl'},
                      ]
);
printf system($exe) ? 'Aww...' : 'Yay! %s bytes', -s $exe;
END { unlink grep defined, $source, $obj, $exe; }
