use strict;
use warnings;
use lib '../lib/blib';
{
    use Alien::FLTK2;
    use ExtUtils::CBuilder;
    my $AF     = Alien::FLTK->new();
    my $CC     = ExtUtils::CBuilder->new();
    my $source = 'hello_world.cxx';
    open(my $FH, '>', $source) || die '...';
    syswrite($FH, <<'') || die '...'; close $FH;
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
        return run();
      }

    my $obj = $CC->compile('C++'                => 1,
                           source               => $source,
                           include_dirs         => [$AF->include_dirs()],
                           extra_compiler_flags => $AF->cxxflags()
    );
    my $exe = $CC->link_executable(objects            => $obj,
                                   extra_linker_flags => $AF->ldflags());
    print system('./' . $exe) ? 'Aww...' : 'Yay!';
    END { unlink grep defined, $source, $obj, $exe; }
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
