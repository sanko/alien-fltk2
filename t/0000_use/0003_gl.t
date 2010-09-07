use strict;
use warnings;
BEGIN { chdir '../..' if not -d '_build'; }
use Test::More;
use File::Temp;
use lib qw[blib/lib];
use Alien::FLTK2;
use ExtUtils::CBuilder;
$|++;
my $CC = ExtUtils::CBuilder->new(quiet => 1);
my $AF = Alien::FLTK2->new();
exit plan skip_all => 'GL is missing' if !$AF->config->{'GL'};
plan tests => 3;
my ($FH, $SRC)
    = File::Temp->tempfile('alien_fltk_t0003_XXXX',
                           TMPDIR  => 1,
                           UNLINK  => 1,
                           SUFFIX  => '.cxx',
                           CLEANUP => 1
    );

#die $AF->library_path;
syswrite($FH, <<'CPP') || BAIL_OUT("Failed to write to $SRC: $!"); close $FH;
#include <fltk/gl.h>
#include <fltk/GlWindow.h>
#include <fltk/run.h>
using namespace fltk;
float theta     = 0.0f;
float speed     = 0.0f;
int   direction = -1;
int   range     = 12;
class MyGlWindow : public GlWindow {
public:
    MyGlWindow( int x, int y, int w, int h ) :
            GlWindow( x, y, w, h, "'Hello, World' ...OpenGL style" ) { }
private:
    void draw( ) {
        if ( !valid() ) {
            valid( 1 );
            glLoadIdentity();
            glViewport( 0, 0, w(), h() );
        }
        glClearColor( 0, 0, 0, 0 );
        glClear ( GL_COLOR_BUFFER_BIT );
        glPushMatrix ();
        glRotatef ( theta, 0.0f, 0.0f, 1.0f );
        glBegin ( GL_TRIANGLES );
        glColor3f ( 1.0f, 0.0f, 0.0f );
        glVertex2f ( 0.0f, 1.0f );
        glColor3f ( 0.0f, 1.0f, 0.0f );
        glVertex2f ( 0.87f, -0.5f );
        glColor3f ( 0.0f, 0.0f, 1.0f );
        glVertex2f ( -0.87f, -0.5f );
        glEnd();
        glPopMatrix();
        theta += speed;
        glsetcolor( fltk::WHITE );
        glsetfont( labelfont(), labelsize() * 3 );
        gldrawtext( "Hello, World!", -.4, 0 );
    };
};
MyGlWindow* gl = new MyGlWindow( 100, 100, 500, 500 );
void tick( void * v ) {
    if ( speed > range ) {
        direction = -1;
    }
    else if ( speed < -range ) {
        direction = 1;
    }
    speed += ( 0.1 * direction );
    gl->redraw();
    repeat_timeout( 0.01, tick, v );
}
int main( int argc, char **argv ) {
    gl->end();                   /* Showing the window causes the test to fail
    add_timeout( 0.01, tick, &gl ); on X11 w/o a display. Testing the creation
    gl->show(argc, argv);           of the window and widget should be enough.
    wait(0.1);                   */
    gl->hide();
    return 0;
}
CPP
my $OBJ = $CC->compile('C++'                => 1,
                       source               => $SRC,
                       include_dirs         => [$AF->include_dirs()],
                       extra_compiler_flags => $AF->cxxflags()
);
ok($OBJ, 'Compile with FLTK headers');
my $EXE = eval {
    $CC->link_executable(objects            => $OBJ,
                         extra_linker_flags => $AF->ldflags(qw[gl]));
};
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

__END__
use strict;
use warnings;
use Alien::FLTK2;
use ExtUtils::CBuilder;
my $AF     = Alien::FLTK2->new();
my $CC     = ExtUtils::CBuilder->new();
my $source = 'gl_hello_world.cxx';
open(my $FH, '>', $source) || die '...';
syswrite($FH, <<'') || die '...'; close $FH;
#line 11 "0002_gl.pl"
#include <fltk/gl.h>
#include <fltk/GlWindow.h>
#include <fltk/run.h>
using namespace fltk;
float theta     = 0.0f;
float speed     = 0.0f;
int   direction = -1;
int   range     = 12;
class MyGlWindow : public GlWindow {
public:
    MyGlWindow( int x, int y, int w, int h ) :
            GlWindow( x, y, w, h, "'Hello, World' ...OpenGL style" ) { }
private:
    void draw( ) {
        if ( !valid() ) {
            valid( 1 );
            glLoadIdentity();
            glViewport( 0, 0, w(), h() );
        }
        glClearColor( 0, 0, 0, 0 );
        glClear ( GL_COLOR_BUFFER_BIT );
        glPushMatrix ();
        glRotatef ( theta, 0.0f, 0.0f, 1.0f );
        glBegin ( GL_TRIANGLES );
        glColor3f ( 1.0f, 0.0f, 0.0f );
        glVertex2f ( 0.0f, 1.0f );
        glColor3f ( 0.0f, 1.0f, 0.0f );
        glVertex2f ( 0.87f, -0.5f );
        glColor3f ( 0.0f, 0.0f, 1.0f );
        glVertex2f ( -0.87f, -0.5f );
        glEnd();
        glPopMatrix();
        theta += speed;
        glsetcolor( fltk::WHITE );
        glsetfont( labelfont(), labelsize() * 3 );
        gldrawtext( "Hello, World!", -.4, 0 );
    };
};
MyGlWindow* gl = new MyGlWindow( 100, 100, 500, 500 );
void tick( void * v ) {
    if ( speed > range ) {
        direction = -1;
    }
    else if ( speed < -range ) {
        direction = 1;
    }
    speed += ( 0.1 * direction );
    gl->redraw();
    repeat_timeout( 0.01, tick, v );
}
int main( int argc, char **argv ) {
    gl->show();
    add_timeout( 0.01, tick, &gl );
    return run();
}

my $obj = $CC->compile(source               => $source,
                       include_dirs         => [$AF->include_dirs()],
                       extra_compiler_flags => $AF->cxxflags()
);
my $exe = $CC->link_executable(objects            => $obj,
                               extra_linker_flags => [$AF->ldflags(qw[gl])]);
printf system('./' . $exe) ? 'Aww...' : 'Yay! %s bytes', -s $exe;
END { unlink grep defined, $source, $obj, $exe; }

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
