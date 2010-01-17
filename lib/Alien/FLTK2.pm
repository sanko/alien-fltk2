package Alien::FLTK2;
{
    use strict;
    use warnings;
    use File::Spec::Functions qw[catdir rel2abs canonpath];
    our $BASE = 0; our $SVN = 6970; our $DEV = 0; our $VERSION = sprintf('%d.%05d' . ($DEV ? '_%03d' : ''), $BASE, $SVN, $DEV);
    my $_config = eval do { local $/; <DATA> }
        or warn
        "Couldn't load Alien::FLTK2 configuration data: $@\n Using defaults";
    close DATA;
    sub new { return bless \$|, shift; }
    sub config   { return $_config; }
    sub revision { return $SVN; }
    sub branch   { return $_config->{'branch'} }

    sub include_dirs {
        my ($self) = @_;
        my @return = keys %{
              $self->config->{'include_dirs'}
            ? $self->config->{'include_dirs'}
            : ()
            };
        for my $path (catdir(qw[.. .. blib arch Alien FLTK2]),
                      catdir(qw[. blib arch Alien FLTK2]),
                      catdir(qw[Alien FLTK]))
        {   foreach my $inc (@INC) {
                next unless defined $inc and !ref $inc;
                my $dir = rel2abs(
                     catdir($inc, $path, 'include', 'fltk-' . $self->branch));
                return ($dir, @return) if -d $dir && -r $dir;
            }
        }
        return undef;
    }

    sub library_path {
        my ($self) = @_;
        for my $path (catdir(qw[.. .. blib arch Alien FLTK2]),
                      catdir(qw[. blib arch Alien FLTK2]),
                      catdir(qw[Alien FLTK2]))
        {   foreach my $inc (@INC) {
                next unless defined $inc and !ref $inc;
                my $dir = rel2abs(
                        catdir($inc, $path, 'libs', 'fltk-' . $self->branch));
                return $dir if -d $dir && -r $dir;
            }
        }
        return undef;
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
        my $LDSTATIC = sprintf '-L%s %s/libfltk%s%s %s',
            $libdir, $libdir, ($self->branch eq '1.3.x' ? '' : '2'),
            $SHAREDSUFFIX,
            ($self->config->{'ldflags'} ? $self->config->{'ldflags'} : '');
        my $LDFLAGS = "-L$libdir "
            . ($self->config->{'ldflags'} ? $self->config->{'ldflags'} : '');
        my $LIBS = sprintf '%s/libfltk%s%s', $libdir,
            ($self->branch eq '1.3.x' ? '' : '2'),
            $SHAREDSUFFIX;
        if (grep {m[forms]} @args) {
            $LDFLAGS = sprintf '-lfltk%s_forms %s',
                ($self->branch eq '1.3.x' ? '' : '2'), $LDFLAGS;
            $LDSTATIC = sprintf '$libdir/libfltk%s_forms%s %s',
                $libdir, ($self->branch eq '1.3.x' ? '' : '2'), $SHAREDSUFFIX,
                $$LDSTATIC;
            $LIBS = sprintf '%s %s/libfltk%s_forms%s',
                $LIBS, $libdir, ($self->branch eq '1.3.x' ? '' : '2'),
                $SHAREDSUFFIX;
        }
        if ((grep {m[gl]} @args) && $self->config->{'GL'}) {
            my $LIBGL = $self->config->{'GL'};
            $LDFLAGS = sprintf '-lfltk%s_gl %s %s',
                ($self->branch eq '1.3.x' ? '' : '2'),
                $LIBGL, $LDFLAGS;
            $LDSTATIC = sprintf '%s/libfltk%s_gl%s %s %s',
                $libdir, ($self->branch eq '1.3.x' ? '' : '2'),
                $SHAREDSUFFIX, $LIBGL, $LDSTATIC;
            $LIBS = sprintf '%s %s/libfltk%s_gl%s',
                $LIBS, $libdir,
                ($self->branch eq '1.3.x' ? '' : '2'),
                $SHAREDSUFFIX;
        }
        if ((grep {m[images]} @args) && $self->config->{'ldflags_image'}) {
            $LDFLAGS  = $self->config->{'ldflags_image'} . " $LDFLAGS";
            $LDSTATIC = sprintf '%s/libfltk%s_images%s %s %s',
                $libdir, ($self->branch eq '1.3.x' ? '' : '2'),
                $SHAREDSUFFIX, $LDSTATIC, $self->config->{'ldflags_image'};
        }
        return (
             ((grep {m[static]} @args) ? $LDSTATIC : $LDFLAGS) . ' -lsupc++');
    }

    sub capabilities {
        my ($self) = @_;
        my @caps;
        push @caps, 'gl' if $self->config->{'config'}{'HAVE_GL'};

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

Returns the SVN brance of the source L<Alien::FLTK2|Alien::FLTK2> was built
with.

Currently, L<Alien::FLTK2|Alien::FLTK2> defaults to the 2.0.x branch but it is
capable of building the more stable 1.3.x branch.

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

__DATA__
do{ my $x = {
  AR                           => "C:\\MinGW\\bin\\ar.EXE crs",
  GL                           => " -lglu32 -lopengl32 ",
  _a                           => ".a",
  automated_testing            => 0,
  branch                       => "2.0.x",
  branch_package               => "inc::MBX::Alien::FLTK::Branch::OneThree",
  cc                           => "gcc",
  config                       => {
                                    BORDER_WIDTH                => 2,
                                    BOXX_OVERLAY_BUGS           => 0,
                                    CLICK_MOVES_FOCUS           => 0,
                                    FLTK_DATADIR                => "",
                                    FLTK_DOCDIR                 => "",
                                    HAVE_DIRENT_H               => undef,
                                    HAVE_DLOPEN                 => 0,
                                    HAVE_EXCEPTIONS             => undef,
                                    HAVE_GL                     => 1,
                                    "HAVE_GLXGETPROCADDRESSARB" => undef,
                                    HAVE_GL_GLU_H               => 1,
                                    HAVE_GL_OVERLAY             => "HAVE_OVERLAY",
                                    HAVE_ICONV                  => 0,
                                    HAVE_LIBJPEG                => undef,
                                    HAVE_LIBPNG                 => undef,
                                    HAVE_LIBPNG_PNG_H           => undef,
                                    HAVE_LIBZ                   => undef,
                                    HAVE_LOCAL_JPEG_H           => undef,
                                    HAVE_LOCAL_PNG_H            => undef,
                                    HAVE_NDIR_H                 => undef,
                                    HAVE_OVERLAY                => 0,
                                    HAVE_PNG_H                  => undef,
                                    HAVE_PTHREAD                => undef,
                                    HAVE_PTHREAD_H              => undef,
                                    HAVE_SCANDIR                => undef,
                                    HAVE_SCANDIR_POSIX          => undef,
                                    HAVE_SNPRINTF               => 1,
                                    HAVE_STRCASECMP             => undef,
                                    HAVE_STRDUP                 => undef,
                                    HAVE_STRINGS_H              => 1,
                                    HAVE_STRING_H               => 1,
                                    HAVE_STRLCAT                => undef,
                                    HAVE_STRLCPY                => undef,
                                    HAVE_STRNCASECMP            => undef,
                                    HAVE_SYS_DIR_H              => undef,
                                    HAVE_SYS_NDIR_H             => undef,
                                    HAVE_SYS_NSTRING_H          => undef,
                                    HAVE_SYS_SELECT_H           => undef,
                                    HAVE_SYS_STDTYPES_H         => undef,
                                    HAVE_VSNPRINTF              => 1,
                                    HAVE_XDBE                   => 0,
                                    HAVE_XINERAMA               => 0,
                                    IGNORE_NUMLOCK              => 1,
                                    SGI320_BUG                  => 0,
                                    U16                         => "unsigned short",
                                    U32                         => "unsigned",
                                    U64                         => undef,
                                    USE_CAIRO                   => 0,
                                    USE_CLIPOUT                 => 0,
                                    USE_COLORMAP                => 1,
                                    USE_GLEW                    => 0,
                                    USE_GL_OVERLAY              => 0,
                                    USE_MULTIMONITOR            => 1,
                                    USE_OVERLAY                 => 0,
                                    USE_POLL                    => 0,
                                    USE_PROGRESSIVE_DRAW        => 1,
                                    USE_QUARTZ                  => undef,
                                    USE_STOCK_BRUSH             => 1,
                                    USE_X11                     => undef,
                                    "USE_X11_MULTITHREADING"    => 0,
                                    USE_XCURSOR                 => undef,
                                    USE_XDBE                    => "HAVE_XDBE",
                                    USE_XFT                     => 0,
                                    USE_XIM                     => 1,
                                    USE_XINERAMA                => 0,
                                    USE_XSHM                    => 0,
                                    WORDS_BIGENDIAN             => 0,
                                    __APPLE_QD__                => undef,
                                    __APPLE_QUARTZ__            => undef,
                                  },
  cxxflags                     => " -mwindows -DWIN32  ",
  errors                       => [],
  extract                      => "D:\\Devel\\alien-fltk\\working\\extract",
  extract_dir                  => "working/extract/",
  "gmtime"                     => "Sun Jan 17 00:09:49 2010",
  headers                      => "C:\\perl\\site\\lib\\Alien\\FLTK2\\include",
  headers_path                 => "fltk",
  image_flags                  => " -lfltk_images -lfltk_png -lfltk_z -lfltk_images -lfltk_jpeg",
  include_dirs                 => {},
  "include_path_compatability" => "/fltk/compat",
  include_path_images          => "/images",
  ldflags                      => " -lfltk2    -mwindows -lmsimg32 -lole32 -luuid -lcomctl32 -lwsock32    -mwindows -lmsimg32 -lole32 -luuid -lcomctl32 -lwsock32    -mwindows -lmsimg32 -lole32 -luuid -lcomctl32 -lwsock32 ",
  ldflags_image                => " -lfltk2_images -lfltk2_png -lfltk2_z -lfltk2_images -lfltk2_jpeg ",
  library_paths                => {},
  libs                         => [
                                    "D:\\Devel\\alien-fltk\\working\\extract\\fltk-2.0.x-r6970\\lib\\libfltk2.a",
                                    "D:\\Devel\\alien-fltk\\working\\extract\\fltk-2.0.x-r6970\\lib\\libfltk2_gl.a",
                                    "D:\\Devel\\alien-fltk\\working\\extract\\fltk-2.0.x-r6970\\lib\\libfltk2_glut.a",
                                    "D:\\Devel\\alien-fltk\\working\\extract\\fltk-2.0.x-r6970\\lib\\libfltk2_images.a",
                                    "D:\\Devel\\alien-fltk\\working\\extract\\fltk-2.0.x-r6970\\lib\\libfltk2_jpeg.a",
                                    "D:\\Devel\\alien-fltk\\working\\extract\\fltk-2.0.x-r6970\\lib\\libfltk2_png.a",
                                    "D:\\Devel\\alien-fltk\\working\\extract\\fltk-2.0.x-r6970\\lib\\libfltk2_z.a",
                                  ],
  libs_source                  => {
                                    fltk2        => {
                                                      directory => "src",
                                                      source    => [
                                                                     "scandir.c",
                                                                     "string.c",
                                                                     "utf.c",
                                                                     "vsnprintf.c",
                                                                     "add_idle.cxx",
                                                                     "addarc.cxx",
                                                                     "addcurve.cxx",
                                                                     "Adjuster.cxx",
                                                                     "AlignGroup.cxx",
                                                                     "AnsiWidget.cxx",
                                                                     "args.cxx",
                                                                     "BarGroup.cxx",
                                                                     "bmpImage.cxx",
                                                                     "Browser.cxx",
                                                                     "Browser_load.cxx",
                                                                     "Button.cxx",
                                                                     "CheckButton.cxx",
                                                                     "Choice.cxx",
                                                                     "clip.cxx",
                                                                     "Clock.cxx",
                                                                     "Color.cxx",
                                                                     "color_chooser.cxx",
                                                                     "ComboBox.cxx",
                                                                     "compose.cxx",
                                                                     "Cursor.cxx",
                                                                     "CycleButton.cxx",
                                                                     "default_glyph.cxx",
                                                                     "Dial.cxx",
                                                                     "DiamondBox.cxx",
                                                                     "dnd.cxx",
                                                                     "drawtext.cxx",
                                                                     "EngravedLabel.cxx",
                                                                     "error.cxx",
                                                                     "event_key_state.cxx",
                                                                     "file_chooser.cxx",
                                                                     "FileBrowser.cxx",
                                                                     "FileChooser.cxx",
                                                                     "FileChooser2.cxx",
                                                                     "FileIcon.cxx",
                                                                     "FileInput.cxx",
                                                                     "filename_absolute.cxx",
                                                                     "filename_ext.cxx",
                                                                     "filename_isdir.cxx",
                                                                     "filename_list.cxx",
                                                                     "filename_match.cxx",
                                                                     "filename_name.cxx",
                                                                     "fillrect.cxx",
                                                                     "Fl_Menu_Item.cxx",
                                                                     "FloatInput.cxx",
                                                                     "fltk_theme.cxx",
                                                                     "Font.cxx",
                                                                     "gifImage.cxx",
                                                                     "Group.cxx",
                                                                     "GSave.cxx",
                                                                     "HelpView.cxx",
                                                                     "HighlightButton.cxx",
                                                                     "Image.cxx",
                                                                     "Input.cxx",
                                                                     "InputBrowser.cxx",
                                                                     "InvisibleWidget.cxx",
                                                                     "Item.cxx",
                                                                     "key_name.cxx",
                                                                     "LightButton.cxx",
                                                                     "list_fonts.cxx",
                                                                     "load_plugin.cxx",
                                                                     "lock.cxx",
                                                                     "Menu.cxx",
                                                                     "Menu_add.cxx",
                                                                     "Menu_global.cxx",
                                                                     "Menu_popup.cxx",
                                                                     "MenuBar.cxx",
                                                                     "MenuWindow.cxx",
                                                                     "message.cxx",
                                                                     "MultiImage.cxx",
                                                                     "NumericInput.cxx",
                                                                     "numericsort.cxx",
                                                                     "Output.cxx",
                                                                     "OvalBox.cxx",
                                                                     "overlay_rect.cxx",
                                                                     "own_colormap.cxx",
                                                                     "PackedGroup.cxx",
                                                                     "path.cxx",
                                                                     "PlasticBox.cxx",
                                                                     "PopupMenu.cxx",
                                                                     "Preferences.cxx",
                                                                     "ProgressBar.cxx",
                                                                     "RadioButton.cxx",
                                                                     "readimage.cxx",
                                                                     "RepeatButton.cxx",
                                                                     "ReturnButton.cxx",
                                                                     "RoundBox.cxx",
                                                                     "RoundedBox.cxx",
                                                                     "run.cxx",
                                                                     "Scrollbar.cxx",
                                                                     "ScrollGroup.cxx",
                                                                     "scrollrect.cxx",
                                                                     "setcolor.cxx",
                                                                     "setdisplay.cxx",
                                                                     "setvisual.cxx",
                                                                     "ShadowBox.cxx",
                                                                     "ShapedWindow.cxx",
                                                                     "SharedImage.cxx",
                                                                     "ShortcutAssignment.cxx",
                                                                     "show_colormap.cxx",
                                                                     "Slider.cxx",
                                                                     "StatusBarGroup.cxx",
                                                                     "StringList.cxx",
                                                                     "Style.cxx",
                                                                     "StyleSet.cxx",
                                                                     "Symbol.cxx",
                                                                     "SystemMenuBar.cxx",
                                                                     "TabGroup.cxx",
                                                                     "TabGroup2.cxx",
                                                                     "TextBuffer.cxx",
                                                                     "TextDisplay.cxx",
                                                                     "TextEditor.cxx",
                                                                     "ThumbWheel.cxx",
                                                                     "TiledGroup.cxx",
                                                                     "TiledImage.cxx",
                                                                     "Tooltip.cxx",
                                                                     "UpBox.cxx",
                                                                     "Valuator.cxx",
                                                                     "ValueInput.cxx",
                                                                     "ValueOutput.cxx",
                                                                     "ValueSlider.cxx",
                                                                     "Widget.cxx",
                                                                     "Widget_draw.cxx",
                                                                     "WidgetAssociation.cxx",
                                                                     "Window.cxx",
                                                                     "Window_fullscreen.cxx",
                                                                     "Window_hotspot.cxx",
                                                                     "Window_iconize.cxx",
                                                                     "WizardGroup.cxx",
                                                                     "xbmImage.cxx",
                                                                     "xpmImage.cxx",
                                                                   ],
                                                    },
                                    fltk2_gl     => {
                                                      directory => "OpenGL",
                                                      source    => [
                                                                     "Fl_Gl_Choice.cxx",
                                                                     "Fl_Gl_Overlay.cxx",
                                                                     "Fl_Gl_Window.cxx",
                                                                     "gl_draw.cxx",
                                                                     "gl_start.cxx",
                                                                   ],
                                                    },
                                    fltk2_glut   => {
                                                      directory => "glut",
                                                      source    => ["glut_compatability.cxx", "glut_font.cxx"],
                                                    },
                                    fltk2_images => {
                                                      directory => "images",
                                                      source    => [
                                                                     "FileIcon2.cxx",
                                                                     "Fl_Guess_Image.cxx",
                                                                     "fl_jpeg.cxx",
                                                                     "fl_png.cxx",
                                                                     "HelpDialog.cxx",
                                                                     "images_core.cxx",
                                                                     "pnmImage.cxx",
                                                                     "xpmFileImage.cxx",
                                                                   ],
                                                    },
                                    fltk2_jpeg   => {
                                                      directory => "images/libjpeg",
                                                      source    => [
                                                                     "jmemnobs.c",
                                                                     "jcapimin.c",
                                                                     "jcapistd.c",
                                                                     "jccoefct.c",
                                                                     "jccolor.c",
                                                                     "jcdctmgr.c",
                                                                     "jchuff.c",
                                                                     "jcinit.c",
                                                                     "jcmainct.c",
                                                                     "jcmarker.c",
                                                                     "jcmaster.c",
                                                                     "jcomapi.c",
                                                                     "jcparam.c",
                                                                     "jcphuff.c",
                                                                     "jcprepct.c",
                                                                     "jcsample.c",
                                                                     "jctrans.c",
                                                                     "jdapimin.c",
                                                                     "jdapistd.c",
                                                                     "jdatadst.c",
                                                                     "jdatasrc.c",
                                                                     "jdcoefct.c",
                                                                     "jdcolor.c",
                                                                     "jddctmgr.c",
                                                                     "jdhuff.c",
                                                                     "jdinput.c",
                                                                     "jdmainct.c",
                                                                     "jdmarker.c",
                                                                     "jdmaster.c",
                                                                     "jdmerge.c",
                                                                     "jdphuff.c",
                                                                     "jdpostct.c",
                                                                     "jdsample.c",
                                                                     "jdtrans.c",
                                                                     "jerror.c",
                                                                     "jfdctflt.c",
                                                                     "jfdctfst.c",
                                                                     "jfdctint.c",
                                                                     "jidctflt.c",
                                                                     "jidctfst.c",
                                                                     "jidctint.c",
                                                                     "jidctred.c",
                                                                     "jquant1.c",
                                                                     "jquant2.c",
                                                                     "jutils.c",
                                                                     "jmemmgr.c",
                                                                   ],
                                                    },
                                    fltk2_png    => {
                                                      directory => "images/libpng",
                                                      include   => "zlib",
                                                      source    => [
                                                                     "png.c",
                                                                     "pngset.c",
                                                                     "pngget.c",
                                                                     "pngrutil.c",
                                                                     "pngtrans.c",
                                                                     "pngwutil.c",
                                                                     "pngread.c",
                                                                     "pngrio.c",
                                                                     "pngwio.c",
                                                                     "pngwrite.c",
                                                                     "pngrtran.c",
                                                                     "pngwtran.c",
                                                                     "pngmem.c",
                                                                     "pngerror.c",
                                                                     "pngpread.c",
                                                                   ],
                                                    },
                                    fltk2_z      => {
                                                      directory => "images/zlib",
                                                      source    => [
                                                                     "adler32.c",
                                                                     "compress.c",
                                                                     "crc32.c",
                                                                     "gzio.c",
                                                                     "uncompr.c",
                                                                     "deflate.c",
                                                                     "trees.c",
                                                                     "zutil.c",
                                                                     "inflate.c",
                                                                     "inftrees.c",
                                                                     "inffast.c",
                                                                     "infblock.c",
                                                                     "infcodes.c",
                                                                     "infutil.c",
                                                                   ],
                                                    },
                                  },
  md5_bz2                      => "f78976d0ba1a5c845e14f4df96d580a0",
  md5_gz                       => "8159cabebbd1b5b774b277827aa4e030",
  os                           => "MSWin32",
  platform                     => ["Windows", "MinGW"],
  release_testing              => 1,
  snapshot                     => "D:\\Devel\\alien-fltk\\working\\snapshot",
  snapshot_dir                 => "working/snapshot/",
  "snapshot_mirror_location"   => "New Jersey, USA",
  snapshot_mirror_uri          => "http://ftp2.easysw.com/pub/fltk/snapshots/fltk-1.3.x-r7008.tar.gz",
  snapshot_path                => "D:\\Devel\\alien-fltk\\working\\snapshot\\fltk-2.0.x-r6970.tar.gz",
  svn                          => 6970,
  test_suite                   => ["t/0000_use/0001_use.t", "t/0000_use/0002_exe.t"],
  threads                      => 1,
  timestamp_config_h           => 1263687048,
  timestamp_configure          => 1263687048,
  use_cairo                    => 0,
}; $x; }
