package MBX::Alien::FLTK::Win32;
{
    use strict;
    use warnings;
    use Carp qw[];
    use Config qw[%Config];
    use lib qw[.. ../..];
    use MBX::Alien::FLTK::Utility qw[_o _a _dir _rel _abs];
    use base 'MBX::Alien::FLTK';
    sub new { bless \$0, shift }

    sub configure {
        my ($self) = @_;

        # Safe
        return $self->SUPER::configure()
            if MBX::Alien::FLTK::Utility::can_run('sh');

        # Stupid
        open(my $CONFIGH_IN, '<', 'configh.in')
            || Carp::confess 'Failed to open configh.in';
        sysread($CONFIGH_IN, my $config, -s $CONFIGH_IN) == -s $CONFIGH_IN
            || Carp::confess 'Failed to slurp configh.in';
        close $CONFIGH_IN;

        #
        my %define = (    # I should/could cache these just in case
            WORDS_BIGENDIAN => '#define WORDS_BIGENDIAN ' . (
                (         # This one's easy...
                   join(' ',
                        map { sprintf '%#02x', $_ }
                            unpack('W*', pack('L', 0x12345678))) eq
                       '0x12 0x34 0x56 0x78'
                ) ? 1 : 0
            ),
            U16     => '',
            U32     => '',
            U64     => '',
            HAVE_GL => (MBX::Alien::FLTK::Utility::find_h('gl.h')
                        ? '#define HAVE_GL 1'
                        : '#undef HAVE_GL'
            ),
            HAVE_GL_GLU_H => (MBX::Alien::FLTK::Utility::find_h('gl/glu.h')
                              ? '#define HAVE_GL_GLU_H 1'
                              : '#undef HAVE_GL_GLU_H'
            ),
            HAVE_STRING_H => (MBX::Alien::FLTK::Utility::find_h('string.h')
                              ? '#define HAVE_STRING_H 1'
                              : '#undef HAVE_STRING_H'
            ),

            #HAVE_LIBPNG  => MBX::Alien::FLTK::Utility::find_lib('png'),
            #HAVE_LIBZ    => MBX::Alien::FLTK::Utility::find_lib('z'),
            #HAVE_LIBJPEG => MBX::Alien::FLTK::Utility::find_lib('jpeg'),
            #HAVE_PTHREAD
        );
        {
            for my $type (qw[short int long]) {
                my $exe = $self->build_exe({code => <<END });
static long int longval () { return (long int) (sizeof ($type)); }
static unsigned long int ulongval () { return (long int) (sizeof ($type)); }
#include <stdio.h>
#include <stdlib.h>
int main () {
    if (((long int) (sizeof ($type))) < 0) {
        long int i = longval ();
        if (i != ((long int) (sizeof ($type))))
            return 1;
            printf ("%ld", i);
    }
    else {
        unsigned long int i = ulongval ();
        if (i != ((long int) (sizeof ($type))))
            return 1;
        printf ("%lu", i);
    }
    return 0;
}
END
                $define{'__sizeof_' . $type . '__'} = `$exe`;
            }

            #
            if ($define{__sizeof_short__} == 2) {
                $define{'U16'} = '#define U16 unsigned short';
            }
            if ($define{__sizeof_int__} == 4) {
                $define{'U32'} = '#define U32 unsigned';
            }
            else { $define{'U32'} = '#define U32 unsigned long' }
            if ($define{__sizeof_int__} == 8) {
                $define{'U64'} = '#define U64 unsigned';
            }
            elsif ($define{__sizeof_long__} == 8) {
                $define{'U64'} = '#define U64 unsigned long';
            }
        }

        #
        $config =~ s[#undef U16][$define{'U16'}];
        $config =~ s[#undef U32][$define{'U32'}];
        $config =~ s[#undef U64][$define{'U64'}];
        $config =~ s[#define\s+WORDS_BIGENDIAN.+][$define{'WORDS_BIGENDIAN'}];
        $config =~ s[#define\s+HAVE_GL\s.+]      [$define{'HAVE_GL'}];
        $config =~ s[#define\s+HAVE_GL_GLU_H.+]  [$define{'HAVE_GL_GLU_H'}];

        #
        open(my $CONFIG_H, '>', 'config.h')
            || Carp::confess 'Failed to open config.h ';
        syswrite($CONFIG_H, $config) == length($config)
            || Carp::confess 'Failed to write config.h';
        return close $CONFIG_H;
    }
    my %LIBS = (
        'images/libjpeg' => {
            fltk2_jpeg => [
                map { $_ . '.c' }
                    qw[jmemnobs jcapimin jcapistd jccoefct jccolor jcdctmgr
                    jchuff jcinit jcmainct jcmarker jcmaster jcomapi jcparam
                    jcphuff jcprepct jcsample jctrans jdapimin jdapistd jdatadst
                    jdatasrc jdcoefct jdcolor jddctmgr jdhuff jdinput jdmainct
                    jdmarker jdmaster jdmerge jdphuff jdpostct jdsample jdtrans
                    jerror jfdctflt jfdctfst jfdctint jidctflt jidctfst jidctint
                    jidctred jquant1 jquant2 jutils jmemmgr]
            ]
        },
        'images/libpng' => {
            fltk2_png => [
                qw[png.c pngset.c pngget.c pngrutil.c pngtrans.c pngwutil.c
                    pngread.c pngrio.c pngwio.c pngwrite.c pngrtran.c pngwtran.c
                    pngmem.c pngerror.c pngpread.c]
            ]
        },
        'images/zlib' => {
            fltk2_z => [
                qw[adler32.c compress.c crc32.c gzio.c uncompr.c deflate.c
                    trees.c zutil.c inflate.c infblock.c inftrees.c infcodes.c
                    infutil.c inffast.c ]
            ]
        },
        images => {
            fltk2_images => [
                qw[ FileIcon2.cxx  Fl_Guess_Image.cxx fl_jpeg.cxx  fl_png.cxx
                    HelpDialog.cxx images_core.cxx pnmImage.cxx
                    xpmFileImage.cxx ]
            ]
        },
        src => {
            fltk2 => [
                (map { $_ . '.cxx' }
                     qw[add_idle addarc addcurve Adjuster AlignGroup AnsiWidget
                     args BarGroup bmpImage Browser Browser_load Button
                     CheckButton Choice clip Clock Color color_chooser ComboBox
                     compose Cursor CycleButton default_glyph Dial DiamondBox
                     dnd drawtext EngravedLabel error event_key_state
                     file_chooser FileBrowser FileChooser FileChooser2 FileIcon
                     FileInput filename_absolute filename_ext filename_isdir
                     filename_list filename_match filename_name fillrect
                     Fl_Menu_Item FloatInput fltk_theme Font gifImage Group
                     GSave HelpView HighlightButton Image Input InputBrowser
                     InvisibleWidget Item key_name LightButton list_fonts
                     load_plugin lock Menu Menu_add Menu_global Menu_popup
                     MenuBar MenuWindow message MultiImage NumericInput
                     numericsort Output OvalBox overlay_rect own_colormap
                     PackedGroup path PlasticBox PopupMenu Preferences
                     ProgressBar RadioButton readimage RepeatButton
                     ReturnButton RoundBox RoundedBox run Scrollbar ScrollGroup
                     scrollrect setcolor setdisplay setvisual ShadowBox
                     ShapedWindow SharedImage ShortcutAssignment show_colormap
                     Slider StatusBarGroup StringList Style StyleSet Symbol
                     SystemMenuBar TabGroup TabGroup2 TextBuffer TextDisplay
                     TextEditor ThumbWheel TiledGroup TiledImage Tooltip UpBox
                     Valuator ValueInput ValueOutput ValueSlider Widget
                     Widget_draw WidgetAssociation Window Window_fullscreen
                     Window_hotspot Window_iconize WizardGroup xbmImage
                     xpmImage]
                ),
                qw[scandir.c string.c utf.c vsnprintf.c]
            ]
        },
        OpenGL => {
            fltk2_gl => [
                qw[Fl_Gl_Choice.cxx Fl_Gl_Overlay.cxx Fl_Gl_Window.cxx
                    gl_draw.cxx gl_start.cxx]
            ]
        },
        glut => {fltk2_glut => [qw[glut_compatability.cxx glut_font.cxx]]}
    );

    sub build_fltk {
        my ($self, $build) = @_;
        my @lib;
        for my $dir (sort keys %LIBS) {
            chdir $build->base_dir() or die q[Can't go home again!];
            chdir $build->fltk_dir() . "/$dir"
                or die 'Cannot chdir to ' . $build->fltk_dir() . '/' . $dir;
            print "=== making $dir ===\n";
            for my $lib (sort keys %{$LIBS{$dir}}) {
                my @obj;
                for my $src (@{$LIBS{$dir}{$lib}}) {
                    my $obj = _o($src);
                    $obj
                        = $build->up_to_date($src, $obj)
                        ? $obj
                        : sub {
                        print "Compiling $src...\n";
                        return
                            $self->compile(
                                      {source       => $src,
                                       include_path => [
                                               '.',
                                               _rel($build->fltk_dir($build)),
                                               _rel($build->fltk_dir($build)
                                                        . '/fltk/compat/'
                                               ),
                                               _rel($build->fltk_dir($build)
                                                        . '/images/zlib/'
                                               ),
                                               $Config{'incpath'}
                                       ],
                                       verbose  => $build->VERBOSE(),
                                       cxxflags => [$Config{'ccflags'}],
                                       output   => $obj
                                      }
                            );
                        }
                        ->();
                    die sprintf 'Failed to compile %s', $src if !$obj;
                    push @obj, $obj;
                }
                my $_lib = _rel(_dir($build->fltk_dir, 'lib', _a($lib)));
                $lib
                    = $build->up_to_date(\@obj, $_lib)
                    ? $_lib
                    : $self->archive({output  => $_lib,
                                      objects => \@obj,
                                      verbose => $build->VERBOSE()
                                     }
                    );
                die sprintf 'Failed to create %s library', $lib
                    if !$lib;
                push @lib, _abs($lib);
            }
        }
        chdir $build->fltk_dir($self)
            or die q[failed to cd to fltk's base directory];
        return @lib ? 1 : 0;
    }

    sub cflags {
        return MBX::Alien::FLTK::Utility::can_run('sh')
            ? $_[0]->SUPER::cflags($_[1])
            : '-mwindows -DWIN32';
    }

    sub cxxflags {
        return MBX::Alien::FLTK::Utility::can_run('sh')
            ? $_[0]->SUPER::cxxflags($_[1])
            : '-mwindows -DWIN32 -Wno-non-virtual-dtor';
    }

    sub ldflags {
        return MBX::Alien::FLTK::Utility::can_run('sh')
            ? $_[0]->SUPER::ldflags($_[1])
            : '-lfltk2 -mwindows -lmsimg32 -lole32 -luuid -lcomctl32 -lwsock32 -lsupc++';
    }
    1;
}
__END__

$Id$
