package MBX::Alien::FLTK::Platform::Unix;
{
    use strict;
    use warnings;
    use Carp qw[];
    use Config qw[%Config];
    use lib qw[.. ../../../..];
    use MBX::Alien::FLTK::Utility
        qw[_o _a _dir _rel _abs find_h find_lib can_run];
    use MBX::Alien::FLTK;
    use base 'MBX::Alien::FLTK::Base';
    $|++;

    sub configure {
        my ($self, @args) = @_;
        $self->SUPER::configure();    # Get basic config data
        print "Gathering *nix/X11 specific configuration data...\n";
        $self->notes(
            os_ver => ${
                my $x = `uname -r`;
                    $x =~ s|\D||g;
                    \$x
                }
        );

        # Asssumed true since this is *nix
        $self->notes('config')->{'USE_X11'} = !grep {m[^no_x11$]} @args;
        print "have pthread... yes (assumed)\n";
        $self->notes('config')->{'HAVE_PTHREAD'} = 1;
        $self->notes('ldflags' => $self->notes('ldflags') . ' -lpthread ');
        print "have sys/ndir.h... \n";
        $self->notes('config')->{'HAVE_SYS_NDIR_H'}
            = (find_h('sys/ndir.h') ? 1 : undef);
        print "have sys/dir.h... \n";
        $self->notes('config')->{'HAVE_SYS_DIR_H'}
            = (find_h('sys/dir.h') ? 1 : undef);
        print "have ndir.h... \n";
        $self->notes('config')->{'HAVE_NDIR_H'}
            = (find_h('ndir.h') ? 1 : undef);
        {
            print
                'checking whether we have the POSIX compatible scandir() prototype... ';
            my $obj = $self->compile({code => <<"" });
#include <dirent.h>
int func (const char *d, dirent ***list, void *sort) {
    int n = scandir(d, list, 0, (int(*)(const dirent **, const dirent **))sort);
}
int main ( ) {
    return 0;
}

            if ($obj ? 1 : 0) {
                print "yes\n";
                $self->notes('config')->{'HAVE_SCANDIR_POSIX'} = 1;
            }
            else {
                print "no\n";
                $self->notes('config')->{'HAVE_SCANDIR_POSIX'} = undef;
            }
        }

        #
        print 'have overlay... ';

        # Use the X overlay extension for MenuWindow and Tooltips. Pretty
        # much depreciated, this will add a substantial amount of code
        # to manage more than one visual, and has only worked on Irix.
        # (ignored if !USE_X11)
        if (`xprop -root 2>/dev/null | grep -c "SERVER_OVERLAY_VISUALS"`) {
            print "yes\n";
            $self->notes('config')->{'HAVE_OVERLAY'} = 1;
        }
        else { print "no\n" }

        #
        if (!grep {m[^no_x11$]} @args) {
            my $X11_okay = 0;

            # Guess where to find include files, by looking for Xlib.h. First,
            # try using that file with no special directory specified.
            print 'checking for X11/Xlib.h... ';
            my $Xlib_h = find_h('Xlib.h', _x11_());
            if (!$Xlib_h) { print "no\n"; }
            else {
                print "yes ($Xlib_h)\n";
                print 'checking X11/Xlib.h usability... ';
                my $obj = $self->compile(
                         {code => <<'', extra_compiler_flags => "-I$Xlib_h"});
#include <X11/Xlib.h>
#include <stdio.h>
#include <stdlib.h>
int main ( ) {
    XrmInitialize( );
    printf ("1");
    return 0;
}

                if (!$obj) { print "no\n" }
                else {
                    print "yes\n";

                    #LIBS="-lXcursor $LIBS"
                    print 'checking for libX11... ';
                    my $search = _x11_();
                    $search =~ s|include|lib|g;
                    my $X11_lib = find_lib('X11', $search);
                    if (!$X11_lib) { print "not found\n" }
                    else {
                        print "found ($X11_lib)\n";
                        my $exe =
                            $self->link_exe(
                                  {objects            => $obj,
                                   extra_linker_flags => "-L$X11_lib -lX11"
                                  }
                            );
                        $X11_okay = `$exe`
                            || undef;
                        $self->notes(  'cxxflags' => $self->notes('cxxflags')
                                     . " -I$Xlib_h ");
                        $self->notes('ldflags' => " -L$X11_lib -lX11 -lXext "
                                     . $self->notes('ldflags'));
                    }
                }
            }
            if (!$X11_okay) {
                print <<''; exit 0; }
 *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** ***
  Failed to find the X11 libs.
  You probably need to install the X11 development package first. On Debian
  Linux, these are the packages libx11-dev and x-dev. If I'm just missing
  something... patches welcome.
 *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** ***

        }
        if (!grep {m[^no_x11$]} @args) {    # Locate XCursor
            print 'checking for X11/Xcursor/Xcursor.h... ';
            my $Xcursor_h = find_h('X11/Xcursor/Xcursor.h', _x11_());
            if (!$Xcursor_h) { print "no\n"; }
            else {
                print "$Xcursor_h\n";
                print 'checking X11/Xcursor/Xcursor.h usability... ';
                my $obj = $self->compile(
                      {code => <<'', extra_compiler_flags => "-I$Xcursor_h"});
#include <X11/Xcursor/Xcursor.h>
#include <stdio.h>
#include <stdlib.h>
int main ( ) {
        const char * path = XcursorLibraryPath( );
        printf ( "%s",  path ? "1" : "0");
        return 0;
}

                if (!$obj) { print "no\n" }
                else {
                    print "yes\n";

                    #LIBS="-lXcursor $LIBS"
                    print 'checking for libXcursor... ';
                    my $search = _x11_();
                    $search =~ s|include|lib|g;
                    my $Xcursor_lib = find_lib('Xcursor', $search);
                    if (!$Xcursor_lib) { print "not found\n" }
                    else {
                        print "found ($Xcursor_lib)\n";
                        my $exe =
                            $self->link_exe({objects => $obj,
                                             extra_linker_flags =>
                                                 "-L$Xcursor_lib -lXcursor"
                                            }
                            );
                        $self->notes('config')->{'USE_XCURSOR'} = `$exe`
                            || undef;
                        $self->notes(  'cxxflags' => $self->notes('cxxflags')
                                     . " -I$Xcursor_h ");
                        $self->notes('ldflags' => " -L$Xcursor_lib -lXcursor "
                                     . $self->notes('ldflags'));
                    }
                }
            }
            if (!defined $self->notes('config')->{'USE_XCURSOR'}) {
                print <<''; }
 *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** ***
  Failed to find the XCursor libs.
  You probably need to install the X11 development package first. On Debian
  Linux, these are the packages libx11-dev, x-dev, and libxcursor-dev. If I'm
  just missing something... patches welcome.
 *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** ***

        }
        if (!grep {m[^no_x11$]} @args) {    # Locate XI and XInput extensions
            print 'checking for X11/extensions/XI.h... ';
            my $XI_h = find_h('/X11/extensions/XI.h', _x11_());
            if   (!$XI_h) { print "no\n"; }
            else          { print "yes ($XI_h)\n" }
            print 'checking for X11/extensions/XInput.h... ';
            my $XInput_h = find_h('/X11/extensions/XInput.h', _x11_());
            if   (!$XInput_h) { print "no\n"; }
            else              { print "yes ($XInput_h)\n" }
            my $XInput_okay = 0;

            if ($XI_h && $XInput_h) {
                print 'checking X11 Input extensions usability... ';
                my $obj =
                    $self->compile(
                    {code =>
                         <<'', extra_compiler_flags => "-I$XInput_h -I$XI_h"});
#include <X11/extensions/XInput.h>
#include <X11/extensions/XI.h>
#include <stdio.h>
#include <stdlib.h>
int main ( ) {
        printf ("1");
        return 0;
}

                if (!$obj) { print "no\n" }
                else {
                    print "yes\n";
                    print 'checking for libXi... ';
                    my $search = _x11_();
                    $search =~ s|include|lib|g;
                    my $XI_lib = find_lib('Xi', $search);
                    if (!$XI_lib) { print "not found\n" }
                    else {
                        print "found ($XI_lib)\n";
                        my $exe =
                            $self->link_exe(
                                    {objects            => $obj,
                                     extra_linker_flags => "-L$XI_lib -lXi"
                                    }
                            );
                        $XInput_okay = `$exe` || undef;
                        $self->notes(  'cxxflags' => $self->notes('cxxflags')
                                     . " -I$XInput_h -I$XI_h ");
                        $self->notes(  'ldflags' => $self->notes('ldflags')
                                     . " -L$XI_lib -lXi ");
                    }
                }
            }
            if (!$XInput_okay) {
                print <<''; exit 0; }
 *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** ***
  Failed to find the XInput Extension.
  You probably need to install the XInput Extension development package
  first. On Debian Linux, this is the libxi-dev package. If I'm just
  missing something... patches welcome.
 *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** ***

        }
        {
            print "checking string functions...\n";
            if (($self->notes('os') =~ m[^hpux$]i)
                && $self->notes('os_ver') == 1020)
            {   print
                    "\nNot using built-in snprintf function because you are running HP-UX 10.20\n";
                $self->notes('config')->{'HAVE_SNPRINTF'} = undef;
                print
                    "\nNot using built-in vnprintf function because you are running HP-UX 10.20\n";
                $self->notes('config')->{'HAVE_VNPRINTF'} = undef;
            }
            elsif (($self->notes('os') =~ m[^dec_osf$]i)
                   && $self->notes('os_ver') == 40)
            {   print
                    "\nNot using built-in snprintf function because you are running Tru64 4.0.\n";
                $self->notes('config')->{'HAVE_SNPRINTF'} = undef;
                print
                    "\nNot using built-in vnprintf function because you are running Tru64 4.0.\n";
                $self->notes('config')->{'HAVE_VNPRINTF'} = undef;
            }
        }
        {
            my %functions = (
                strdup      => 'HAVE_STRDUP',
                strcasecmp  => 'HAVE_STRCASECMP',
                strncasecmp => 'HAVE_STRNCASECMP',
                strlcat     => 'HAVE_STRLCRT',

                #strlcpy     => 'HAVE_STRLCPY'
            );
            for my $func (keys %functions) {
                printf 'checking for %s... ', $func;
                my $obj = $self->compile({code => <<""});
/* Define $func to an innocuous variant, in case <limits.h> declares $func.
   For example, HP-UX 11i <limits.h> declares gettimeofday.  */
#define $func innocuous_$func
/* System header to define __stub macros and hopefully few prototypes,
    which can conflict with char $func (); below.
    Prefer <limits.h> to <assert.h> if __STDC__ is defined, since
    <limits.h> exists even on freestanding compilers.  */
#ifdef __STDC__
# include <limits.h>
#else
# include <assert.h>
#endif
#undef $func
/* Override any GCC internal prototype to avoid an error.
   Use char because int might match the return type of a GCC
   builtin and then its argument prototype would still apply.  */
#ifdef __cplusplus
extern "C"
#endif
char $func ();
/* The GNU C library defines this for functions which it implements
    to always fail with ENOSYS.  Some functions are actually named
    something starting with __ and the normal name is an alias.  */
#if defined __stub_$func || defined __stub___$func
choke me
#endif
int main () {
    return $func ();
    return 0;
}

                if ($obj) {
                    print "yes\n";
                    $self->notes('config')->{$functions{$func}} = 1;
                }
                else {
                    print "no\n";
                    $self->notes('config')->{$functions{$func}} = undef;
                }
            }
        }
        if (!grep {m[^no_gl$]} @args) {
            my $GL_LIB = '';
            print 'checking for GL/gl.h... ';
            if (!find_h('GL/gl.h')) { print "no\n" }
            else {
                print "okay\n";
                print 'checking OpenGL... ';
                my $exe = $self->build_exe(
                                {code => <<'', extra_linker_flags => '-lGL'});
#include <GL/gl.h>
#include <stdio.h>
#include <stdlib.h>
int main ( ) {
    printf ("1");
    return glXMakeCurrent ();
}

                if (($exe && `$exe`)) {
                    print "yes\n";
                    $GL_LIB = '-lGL';
                }
                else {
                    print "no\n";
                    print 'checking MesaGL... ';
                    my $exe = $self->build_exe(
                            {code => <<'', extra_linker_flags => '-lMesaGL'});
#include <GL/gl.h>
#include <stdio.h>
#include <stdlib.h>
int main ( ) {
    printf ("1");
    return glXMakeCurrent ();
}

                    if (($exe && `$exe`)) {
                        print "yes\n";
                        $GL_LIB = '-lMesaGL';
                    }
                    else { print "no\n" }
                }
                if ($GL_LIB) {
                    print "okay\n";
                    $self->notes('config')->{'HAVE_GL'} = 1;
                    $GL_LIB = '-lMesaGL';

                    #
                    print 'checking GL/glu.h presence... ';
                    my $exe_glu =
                        $self->build_exe(
                        {   code =>
                                <<'', extra_linker_flags => '-lGLU ' . $GL_LIB});
#include <GL/glu.h>
#include <stdio.h>
#include <stdlib.h>
int main ( ) {
    printf ("1");
    return glXMakeCurrent ();
}

                    if (!($exe_glu && `$exe_glu`)) {
                        print "no\n";
                    }
                    else {
                        print "okay\n";
                        $self->notes('config')->{'HAVE_GL_GLU_H'} = 1;
                        $GL_LIB = "-lGLU $GL_LIB";
                    }
                }
            }
            if ($GL_LIB) {
                $self->notes(GL => $GL_LIB);
            }
            else {
                print "GL is disabled\n";
            }
        }
        return 1;
    }

    sub _x11_ {    # Common directories for X headers. Check X11 before X11R\d
        return     # because it is often a symlink to the current release.
            <<'' }
/usr/X11/include
/usr/X11R7/include
/usr/X11R6/include
/usr/X11R5/include
/usr/X11R4/include
/usr/include/X11
/usr/include/X11R7
/usr/include/X11R6
/usr/include/X11R5
/usr/include/X11R4
/usr/local/X11/include
/usr/local/X11R7/include
/usr/local/X11R6/include
/usr/local/X11R5/include
/usr/local/X11R4/include
/usr/local/include/X11
/usr/local/include/X11R7
/usr/local/include/X11R6
/usr/local/include/X11R5
/usr/local/include/X11R4
/usr/X386/include
/usr/x386/include
/usr/XFree86/include/X11
/usr/include
/usr/local/include
/usr/unsupported/include
/usr/athena/include
/usr/local/x11r5/include
/usr/lpp/Xamples/include
/usr/openwin/include
/usr/openwin/share/include

    1;
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
