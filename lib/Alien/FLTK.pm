package Alien::FLTK;
{
    use strict;
    use warnings;
    use Config qw[%Config];
    use File::Spec::Functions qw[catdir rel2abs canonpath];
    use File::Basename;
    use File::Find qw[find];
    our $VERSION_BASE = 0; our $FLTK_SVN = 6841; our $UNSTABLE_RELEASE = 3; our $VERSION = sprintf('%d.%05d' . ($UNSTABLE_RELEASE ? '_%03d' : ''), $VERSION_BASE, $FLTK_SVN, $UNSTABLE_RELEASE);
    sub revision { return $FLTK_SVN; }

    sub include_path {
        my @include = map { -d $_ ? $_ : () } (
                 rel2abs(catdir(qw[blib arch Alien FLTK include])),
                 rel2abs(catdir(dirname(rel2abs(__FILE__)), qw[FLTK include]))
        );
        return $include[0];
    }

    sub library_path {
        my @libs = map { -d $_ ? $_ : () } (
                    rel2abs(catdir(qw[blib arch Alien FLTK libs])),
                    rel2abs(catdir(dirname(rel2abs(__FILE__)), qw[FLTK libs]))
        );
        return $libs[0];
    }

    sub cflags {
        my $CFLAGS = '-I' . Alien::FLTK->include_path();
        if (($Config{'osname'} || $^O) =~ m[MSWin32]) {
            $CFLAGS = "$CFLAGS -mwindows -DWIN32";
        }
        return $CFLAGS;
    }

    sub cxxflags {
        my $CXXFLAGS = Alien::FLTK->cflags();
        if (($Config{'osname'} || $^O) =~ m[MSWin32]) {
            $CXXFLAGS = "$CXXFLAGS -Wno-non-virtual-dtor";
        }
        return $CXXFLAGS;
    }

    sub ldflags {
        my ($self, @args) = @_;
        my $LDLIBS = my $GLLIB = '';
        {
            local $_ = ($Config{'osname'} || $^O);
            if (m[MSWin32]i) {
                $LDLIBS
                    = '-mwindows -lmsimg32 -lole32 -luuid -lcomctl32 -lwsock32 -lsupc++';
                $GLLIB = "-lopengl32"
                    if _find_h('GL/gl.h');    # XXX only if use_gl
                $GLLIB = "-lglu32 $GLLIB" if _find_h('GL/glu.h');
            }
            elsif (m[darwin]i) {    # MacOS X uses Carbon for graphics...
                $LDLIBS = '-framework Carbon -framework ApplicationServices';
                $GLLIB  = '-framework AGL -framework OpenGL';
            }
            else {                # All others are UNIX/X11...
                $LDLIBS
                    = '-lX11 -lXi -lXcursor -lpthread -lm -lXext -lsupc++';
                if (_find_h('GL/gl.h')) {
                    $GLLIB = _find_lib('MesaGL') ? '-lMesaGL' : '-lGL';
                    if (_find_h('GL/glu.h')) {
                        $GLLIB = "-lGLU $GLLIB"     if _find_lib('GLU');
                        $GLLIB = "-lMesaGLU $GLLIB" if _find_lib('MesaGL');
                    }
                }
            }
        }

        #
        my $libdir = Alien::FLTK->library_path();

        # Calculate needed libraries
        my $SHAREDSUFFIX = $Config{'_a'};
        my $LDSTATIC     = "-L$libdir $libdir/libfltk2$SHAREDSUFFIX $LDLIBS";
        my $LDFLAGS      = "-L$libdir -lfltk2 $LDLIBS";
        my $LIBS         = "$libdir/libfltk2$SHAREDSUFFIX";
        my $IMAGELIBS = " -lfltk2_png -lfltk2_z -lfltk2_images -lfltk2_jpeg ";
        if (grep {m[forms]} @args) {
            $LDFLAGS  = "-lfltk2_forms $LDFLAGS";
            $LDSTATIC = "$libdir/libfltk2_forms$SHAREDSUFFIX $LDSTATIC";
            $LIBS     = "$LIBS $libdir/libfltk2_forms$SHAREDSUFFIX";
        }
        if (grep {m[gl]} @args) {
            $LDFLAGS  = "-lfltk2_gl $GLLIB $LDFLAGS";
            $LDSTATIC = "$libdir/libfltk2_gl$SHAREDSUFFIX $GLLIB $LDSTATIC";
            $LIBS     = "$LIBS $libdir/libfltk2_gl$SHAREDSUFFIX";
        }
        if (grep {m[images]} @args) {
            $LDFLAGS = "-lfltk2_images $IMAGELIBS $LDFLAGS";
            $LDSTATIC
                = "$libdir/libfltk2_images$SHAREDSUFFIX $LDSTATIC $IMAGELIBS";
        }
        return ((grep {m[static]} @args) ? $LDSTATIC : $LDFLAGS);
    }

    sub _find_lib {
        my ($find) = @_;
        $find =~ s[([\+\*\.])][\\$1]g;
        my $lib;
        find(
            sub {
                $lib = $File::Find::name
                    if $_ =~ qr[lib$find$Config{'_a'}];
            },
            split ' ',
            $Config{'libpth'}
        );
        return $lib;
    }

    sub _find_h {
        my $file = rel2abs(catdir($Config{'incpath'}, shift));
        my $found = 0;
        find(
            sub {
                $found = 1 if canonpath($File::Find::name) eq $file;
            },
            $Config{'incpath'}
        );
        return $found;
    }
}

=pod

=head1 NAME

Alien::FLTK - Build and use the Fast Light Toolkit binaries

=head1 Description

This distribution builds and installs libraries for the (experimental)
C<2.0.x> branch of the FLTK GUI toolkit.

=head1 Synopsis

    use Alien::FLTK;
    use ExtUtils::CBuilder;
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

    my $obj = $CC->compile(source               => $source,
                           extra_compiler_flags => Alien::FLTK->cxxflags());
    my $exe = $CC->link_executable(
                                  objects            => $obj,
                                  extra_linker_flags => Alien::FLTK->ldflags()
    );
    print system($exe) ? 'Aww...' : 'Yay!';
    END { unlink grep defined, $source, $obj, $exe; }

=head1 Methods

=head2 C<include_path>

    my $include_path = Alien::FLTK->include_path;

Returns the location of the headers installed during the build process.

=head2 C<library_path>

    my $include_path = Alien::FLTK->library_path;

Returns the location of the private libraries we made and installed
during the build process.

=head2 C<cflags>

    my $cflags = Alien::FLTK->cflags;

Returns additional C compiler flags to be used.

=head2 C<cxxflags>

    my $cxxflags = Alien::FLTK->cxxflags;

Returns additional flags to be used to when compiling C++ using FLTK.

=head2 C<ldflags>

    my $ldflags = Alien::FLTK->ldflags(qw[gl images]);

Returns additional linker flags to be used. This method can automatically add
appropriate flags based on how you plan on linking to fltk. Acceptable
arguments are:

=over

=item C<static>

Returns flags to link against a static FLTK library.

I<FLTK's license allows static linking, btw.>

=item C<gl>

Include flags to use GL.

I<This is an experimental option. Depending on your system, this may also
include OpenGL or MesaGL.>

=item C<images>

Include flags to use extra image formats (PNG, JPEG).

=begin TODO

=item C<glut>

Include flags to use FLTK's glut compatibility layer.

=item C<forms>

Include flags to use FLTK's forms compatibility layer.

=end TODO

=back

=head2 C<revision>

    my $revision = Alien::FLTK->revision;

Returns the SVN revision number of the source L<C<Alien::FLTK>|Alien::FLTK>
was built with.

=head1 Bugs

Numerous, I'm sure.

=head1 Notes

=head2 Support Links

=over

=item * Issue Tracker

http://github.com/sanko/alien-fltk/issues

Please only report L<Alien::FLTK|Alien::FLTK> related bugs to this tracker.
For L<FLTK|FLTK> issues, use http://github.com/sanko/fltk-perl/issues/

=item * Commit Log

http://github.com/sanko/alien-fltk/commits/master

=item * Homepage:

http://sanko.github.com/fltk-perl/ is the homepage of the L<FLTK|FLTK>
project.

=item * License:

http://www.perlfoundation.org/artistic_license_2_0

See the L<License and Legal|/"License and Legal"> section of this document.

=item * Mailing List

Once I find someone to host a list for the L<FLTK|FLTK> project, I'll use it
for L<Alien::FLTK|Alien::FLTK> too.

=item * Repository

http://github.com/sanko/alien-fltk/ and you are invited to fork it.

=back

=head2 Requirements

Once installed, L<Alien::FLTK> depends on:

=over

=item L<Config|Config>

=item L<File::Spec::Functions>

=item L<File::Basename>

=item L<File::Find>

=back

=head2 Examples

Please see the L<Synopsis|/"Synopsis"> and the files in the C</example/>.

=head2 Installation

Building the fltk2 libs requires a functioning C++ compiler, bash, and (to
make life easy) a version of make.

The distribution is based on L<Module::Build|Module::Build>, so use the
following procedure:

  perl Build.PL
  ./Build
  ./Build test
  ./Build install

An attempt has been made to work around an incomplete set of build tools. This
fallback requires L<ExtUtils::CBuilder|ExtUtils::CBuilder> and plenty of
begging. Consider it alpha at best.

=head1 To Do

Please see L<Alien::FLTK::Todo|Alien::FLTK::Todo>

=head1 See Also

L<FLTK|FLTK>

=head1 Acknowledgments

=over

=item The FLTK Team - http://www.fltk.org/

=back

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

L<C<Alien::FLTK>|Alien::FLTK> is based in part on the work of the FLTK
project. See http://www.fltk.org/.

=for git $Id$

=cut
