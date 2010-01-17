use strict;
use warnings;
{
    use Alien::FLTK2;
    use ExtUtils::CBuilder;
    my $AF     = Alien::FLTK2->new();
    my $CC     = ExtUtils::CBuilder->new();
    my $source = 'hello_world.cxx';
    open(my $FH, '>', $source) || die '...';
    syswrite($FH, <<'END') || die '...'; close $FH;
    #include <fltk/Box.h>
    #include <fltk/Style.h>
    #include <fltk/Window.h>
    #include <fltk/run.h>

    // fltk group named style bug
    extern fltk::NamedStyle * group_style;

    bool my_theme( ) {
      // Reset to fltk's default theme
      fltk::reset_theme();

      // Change some widget's defaults
      int bgcolor = 0x43434300;
      int textcolor = 0xababab00;
      int selectioncolor = 0x97a8a800;

      fltk::Style * style = fltk::Style::find( "Slider" );
      if ( style ) {
        style->color( bgcolor );
        style->textcolor( textcolor );
        style->buttoncolor( bgcolor );
        style->textsize( 8 );
        style->labelsize( 10 );
        style->labelcolor( textcolor );
        style->highlight_textcolor( 0xFFFF0000 );
      }

      // this is broken...
      // style = fltk::Style::find( "Group" );
      style = group_style;
      if ( style ) {
        style->color( bgcolor );
        style->textcolor( textcolor );
        style->buttoncolor( bgcolor );
        style->textsize( 10 );
        style->labelsize( 10 );
        style->labelcolor( textcolor );
      }

      style = fltk::Style::find( "Widget" );
      if ( style ) {
        style->color( bgcolor );
        style->textcolor( textcolor );
        style->buttoncolor( bgcolor );
        style->textsize( 14 );
        style->labelsize( 14 );
        style->labelcolor( textcolor );
        style->selection_color( selectioncolor );
      }

      // change down box to draw a tad darker than default
      fltk::FrameBox * box;
      box = (fltk::FrameBox *) fltk::Symbol::find( "down_" );
      if ( box ) box->data( "2HHOOAA" );
      return true;
    }

    int main( ) {
      fltk::theme( &my_theme );
      fltk::Window *window = new fltk::Window(300, 180);
      window->begin();
      fltk::Widget *box = new fltk::Widget(20, 40, 260, 100, "Hello, World!");
      box->box(fltk::UP_BOX);
      box->labelfont(fltk::HELVETICA_BOLD_ITALIC);
      box->labelsize(36);
      box->labeltype(fltk::SHADOW_LABEL);
      window->end();
      window->show( );
      return fltk::run();
        // create widgets normally.
        // Any widget with default settings gets the defaults we
        // just set.
    }
END
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
