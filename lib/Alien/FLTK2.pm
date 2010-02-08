package Alien::FLTK2;
{
    use strict;
    use warnings;
    use File::Spec::Functions qw[catdir rel2abs canonpath];
    our $BASE = 0; our $SVN = 6970; our $DEV = 16; our $VERSION = sprintf('%d.%05d' . ($DEV ? '_%03d' : ''), $BASE, $SVN, $DEV);

    sub _md5 {
        return {gz  => '8159cabebbd1b5b774b277827aa4e030',
                bz2 => 'f78976d0ba1a5c845e14f4df96d580a0'
        };
    }
    sub _unique_file { return 'src/Widget.cxx' }

    sub new {
        my ($class, $overrides) = @_;    # XXX - overrides are unsupported
        my $self;
        {
            require File::ShareDir;
            ($self->{'basedir'})
                = (grep { -d $_ && -f catdir($_, 'config.yml') }
                       map { rel2abs($_) } (
                             eval { File::ShareDir::dist_dir('Alien-FLTK2') },
                             'share', '../share', '../../share'
                       )
                );
        }
        if (!defined $self->{'basedir'}) {
            warn 'Fail';
            return ();
        }
        $self->{'define'} = do {
            require YAML::Tiny;
            my $yaml
                = YAML::Tiny->read(catdir($self->{'basedir'}, 'config.yml'));
            warn 'Failed to load Alien::FLTK2 config: ' . YAML::Tiny->errstr()
                if !$yaml;
            $yaml ? $yaml->[0] : {};
        };
        return bless $self, shift;
    }
    sub config   { return +shift->{'define'}; }
    sub revision { return $SVN; }
    sub branch   { return +shift->{'define'}->{'branch'} }

    sub include_dirs {
        my ($self) = @_;
        return canonpath($self->{'basedir'} . '/include');
    }

    sub library_path {
        my ($self) = @_;
        return canonpath($self->{'basedir'} . '/libs');
    }
    sub cflags { return shift->cxxflags(); }

    sub cxxflags {
        my ($self) = @_;
        return $self->config->{'cxxflags'} ? $self->config->{'cxxflags'} : '';
    }

    sub ldflags {    # XXX - Cache this
        my ($self, @args) = @_;

        #
        my $libdir = shift->library_path();

        # Calculate needed libraries
        my $SHAREDSUFFIX
            = $self->config->{'_a'} ? $self->config->{'_a'}
            : $^O =~ '$MSWin32' ? '.a'
            :                     '.o';
        my $LDSTATIC = sprintf '-L%s %s/libfltk2%s %s', $libdir, $libdir,
            $SHAREDSUFFIX,
            ($self->config->{'ldflags'} ? $self->config->{'ldflags'} : '');
        my $LDFLAGS = "-L$libdir -lfltk2 "
            . ($self->config->{'ldflags'} ? $self->config->{'ldflags'} : '');
        my $LIBS = sprintf '%s/libfltk2%s', $libdir, $SHAREDSUFFIX;
        if (grep {m[forms]} @args) {
            $LDFLAGS  = sprintf '-lfltk2_forms %s',            $LDFLAGS;
            $LDSTATIC = sprintf '$libdir/libfltk2_forms%s %s', $libdir,
                $SHAREDSUFFIX,
                $$LDSTATIC;
            $LIBS = sprintf '%s %s/libfltk2_forms%s', $LIBS, $libdir,
                $SHAREDSUFFIX;
        }
        if ((grep {m[gl]} @args) && $self->config->{'GL'}) {
            my $LIBGL = $self->config->{'GL'};
            $LDFLAGS = sprintf '-lfltk2_gl %s %s', $LIBGL, $LDFLAGS;
            $LDSTATIC = sprintf '%s/libfltk2_gl%s %s %s',
                $libdir, $SHAREDSUFFIX, $LIBGL, $LDSTATIC;
            $LIBS = sprintf '%s %s/libfltk2_gl%s',
                $LIBS, $libdir, $SHAREDSUFFIX;
        }
        if (grep {m[images]} @args) {
            my $img_libs = $self->config->{'image_flags'};
            $LDFLAGS  = " $img_libs $LDFLAGS ";
            $LDSTATIC = sprintf '%s/libfltk2_images%s %s %s',
                $libdir, $SHAREDSUFFIX, $img_libs, $LDSTATIC;
        }
        return (
             ((grep {m[static]} @args) ? $LDSTATIC : $LDFLAGS) . ' -lsupc++');
    }

    sub capabilities {
        my ($self) = @_;
        my @caps;
        push @caps, 'gl' if $self->config->{'define'}{'HAVE_GL'};

        # TODO: images, forms, static(?)
        return @caps;
    }
    1
}

=pod

=head1 NAME

Alien::FLTK2 - Build and use the Fast Light Toolkit binaries

=head1 Description

This distribution builds and installs libraries for the (experimental)
C<2.0.x> branch of the FLTK GUI toolkit.

=head1 Synopsis

    use Alien::FLTK2;
    use ExtUtils::CBuilder;
    my $AF     = Alien::FLTK2->new();
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

=head1 Constructor

There are no per-object configuration options as of this version, but there
may be in the future, so any new code using L<Alien::FLTK2|Alien::FLTK2> should
create objects with the C<new> constructor.

    my $AF = Alien::FLTK2->new( );

=head1 Methods

After creating a new L<Alien::FLTK2|Alien::FLTK2> object, use the following
methods to gather information:

=head2 C<include_dirs>

    my @include_dirs = $AF->include_dirs( );

Returns a list of the locations of the headers installed during the build
process and those required for compilation.

=head2 C<library_path>

    my $lib_path = $AF->library_path( );

Returns the location of the private libraries we made and installed
during the build process.

=head2 C<cflags>

    my $cflags = $AF->cflags( );

Returns additional C compiler flags to be used.

=head2 C<cxxflags>

    my $cxxflags = $AF->cxxflags( );

Returns additional flags to be used to when compiling C++ using FLTK.

=head2 C<ldflags>

    my $ldflags = $AF->ldflags( qw[gl images] );

Returns additional linker flags to be used. This method can automatically add
appropriate flags based on how you plan on linking to fltk. Acceptable
arguments are:

=over

=item C<static>

Returns flags to link against a static FLTK library.

FLTK's license allows static linking, but L<Alien::FLTK2|Alien::FLTK2> does not
build static libs. ...yet.

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

=head2 C<branch>

    my $revision = $AF->branch( );

Returns the SVN branch of the source L<Alien::FLTK2|Alien::FLTK2> was built
with. For the C<1.3.x> branch of fltk, see L<Alien::FLTK|Alien::FLTK>.

=head2 C<revision>

    my $revision = $AF->revision( );

Returns the SVN revision number of the source L<Alien::FLTK2|Alien::FLTK2>
was built with.

=head2 C<capabilities>

    my $caps = $AF->capabilities( );

Returns a list of capabilities supported by your L<Alien::FLTK2|Alien::FLTK2>
installation. This list can be handed directly to
L<C<ldflags( )>|Alien::FLTK2/ldflags>.

=head2 C<config>

    my $configuration = $AF->config( );

Returns a hashref containing the raw configuration data collected during
build. This would be helpful when reporting bugs, etc.

=head1 Notes

=head2 Requirements

Prerequisites differ by system...

=over

=item Win32

The fltk2 libs and L<Alien::FLTK2|Alien::FLTK2> both build right out of the box
with MinGW. Further testing is needed for other setups.

=item X11/*nix

X11-based systems require several development packages. On Debian, these may
be installed with...

  > sudo apt-get install libx11-dev
  > sudo apt-get install libxi-dev
  > sudo apt-get install libxcursor-dev

=item Darwin/OSX

Uh, yeah, I have no idea.

=back

=head2 Installation

The distribution is based on L<Module::Build|Module::Build>, so use the
following procedure:

  > perl Build.PL
  > ./Build
  > ./Build test
  > ./Build install

=head2 Support Links

=over

=item * Issue Tracker

http://github.com/sanko/alien-fltk/issues

Please only report L<Alien::FLTK2|Alien::FLTK2> related bugs to this tracker.
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
for L<Alien::FLTK2|Alien::FLTK2> too.

=item * Repository

http://github.com/sanko/alien-fltk/ and you are invited to fork it.

=back

=head2 Examples

Please see the L<Synopsis|/"Synopsis"> and the files in the C</examples/>.

=head2 Bugs

Numerous, I'm sure.

=head2 To Do

Please see L<Alien::FLTK2::Todo|Alien::FLTK2::Todo>

=head1 See Also

L<FLTK|FLTK>, L<Alien::FLTK|Alien::FLTK>

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

L<Alien::FLTK2|Alien::FLTK2> is based in part on the work of the FLTK project.
See http://www.fltk.org/.

=for git $Id$

=cut
