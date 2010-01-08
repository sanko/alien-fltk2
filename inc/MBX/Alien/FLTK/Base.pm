package MBX::Alien::FLTK::Base;
{
    use strict;
    use warnings;
    use Cwd;
    use Config qw[%Config];
    use File::Temp qw[tempfile];
    use File::Find qw[find];
    use Carp qw[carp];
    use base 'Module::Build';
    use lib qw[../../../../inc];
    use MBX::Alien::FLTK::Utility
        qw[_o _a _dir _file _rel _abs _exe find_h find_lib can_run];

    sub fltk_dir {
        my ($self) = @_;
        my $return = $self->notes('fltk_dir');
        return $return if $return;
        $self->notes(
                'fltk_dir' =>
                    _abs(sprintf '%s/src/fltk-%s-r%d', $self->base_dir(),
                         $self->notes('fltk_branch'), $self->notes('fltk_svn')
                    )
        );
        return _dir($self->notes('fltk_dir'));
    }

    sub archive {
        my ($self, $args) = @_;
        my $arch = $args->{'output'};
        my @cmd = ($self->notes('AR'), $arch, @{$args->{'objects'}});
        print STDERR "@cmd\n" if !$self->quiet;
        return MBX::Alien::FLTK::Utility::run(@cmd);
    }

    sub test_exe {
        my ($self, $args) = @_;
        my ($exe,  @obj)  = $self->build_exe($args);
        return if !$exe;
        my $return = !system($exe);
        unlink $exe, @obj;
        return $return;
    }

    sub compile {
        my ($self, $args) = @_;
        my $code = 0;
        if (!$args->{'source'}) {
            (my $FH, $args->{'source'}) = tempfile(
                                     undef, SUFFIX => '.cpp'    #, UNLINK => 1
            );
            syswrite($FH,
                     ($args->{'code'}
                      ? delete $args->{'code'}
                      : 'int main(){return 0;}'
                         )
                         . "\n"
            );
            close $FH;
            $code = 1;
        }
        my $obj = eval {
            $self->cbuilder->compile(
                  ($args->{'source'} !~ m[\.c$] ? ('C++' => 1) : ()),
                  source => $args->{'source'},
                  ($args->{'include_dirs'}
                   ? (include_dirs => $args->{'include_dirs'})
                   : ()
                  ),
                  ($args->{'extra_compiler_flags'}
                   ? (extra_compiler_flags => $args->{'extra_compiler_flags'})
                   : ()
                  )
            );
        };

        #unlink $args->{'source'} if $code;
        return if !$obj;
        return $obj;
    }

    sub link_exe {
        my ($self, $args) = @_;
        my $exe = eval {
            $self->cbuilder->link_executable(
                                     objects            => $args->{'objects'},
                                     extra_linker_flags => (
                                         (  $args->{'extra_linker_flags'}
                                          ? $args->{'extra_linker_flags'}
                                          : ''
                                         )
                                         . ($args->{'source'} =~ m[\.c$] ? ''
                                            : ' -lsupc++'
                                         )
                                     )
            );
        };
        return if !$exe;
        return $exe;
    }

    sub build_exe {
        my ($self, $args) = @_;
        my $obj = $self->compile($args);
        return if !$obj;
        $args->{'objects'} = [$obj];
        my $exe = $self->link_exe($args);
        return if !$exe;
        return ($exe, $obj) if wantarray;
        unlink $obj;
        return $exe;
    }

    sub _archdir {
        my ($self, $p) = @_;
        my ($vol, $dir, $file) = File::Spec->splitpath($p || '');
        return
            File::Spec->catfile($self->install_destination('arch'),
                                qw[Alien FLTK], File::Spec->splitdir($dir),
                                $file);
    }

    sub ACTION_copy_headers {
        my ($self) = @_;
        $self->depends_on('fetch_fltk');
        $self->depends_on('extract_fltk');
        $self->depends_on('configure_fltk');
        $self->depends_on('write_config_h');
        $self->depends_on('build_fltk');
        my $headers_location =
            _dir($self->fltk_dir(),
                 ($self->notes('fltk_branch') eq '1.3.x'
                  ? 'FL'
                  : 'fltk'
                 )
            );
        if (!chdir $headers_location) {
            printf 'Failed to cd to %s to copy headers', $headers_location;
            exit 0;
        }
        find {
            wanted => sub {
                return if -d;
                $self->copy_if_modified(
                            from => $File::Find::name,
                            to   => _dir(
                                       $self->base_dir(),
                                       qw[blib arch Alien FLTK include],
                                       'fltk-' . $self->notes('fltk_branch'),
                                       ($self->notes('fltk_branch') eq '1.3.x'
                                        ? 'FL'
                                        : 'fltk'
                                       ),
                                       $File::Find::name
                            )
                );
            },
            no_chdir => 1
            },
            '.';
        if (!chdir _dir($self->fltk_dir())) {
            print 'Failed to cd to fltk\'s include directory';
            exit 0;
        }
        $self->copy_if_modified(from => 'config.h',
                                to =>
                                    _dir(
                                        $self->base_dir(),
                                        qw[blib arch Alien FLTK include],
                                        'fltk-' . $self->notes('fltk_branch'),
                                        'config.h'
                                    )
        );
        print "Installing headers...\n" if !$self->quiet;
        if (!chdir $self->base_dir()) {
            printf 'Failed to return to %s', $self->base_dir();
            exit 0;
        }
        $self->notes(headers => $self->_archdir('include'));
        return 1;
    }

    # Configure
    sub configure {
        my ($self, $args) = @_;
        $self->notes('ldflags' => ($self->notes('fltk_branch') eq '1.3.x'
                                   ? ' -lfltk '
                                   : ' -lfltk2 '
                     )
        );
        $self->notes('_a'       => $Config{'_a'});
        $self->notes('cxxflags' => ' ');
        $self->notes('GL'       => ' ');
        $self->notes(
            'image_flags' => (
                $self->notes('fltk_branch') eq '1.3.x'
                ? ' -lfltk_images -lfltk_png -lfltk_z -lfltk_images -lfltk_jpeg '
                : ' -lfltk2_images -lfltk2_png -lfltk2_z -lfltk2_images -lfltk2_jpeg '
            )
        );
        $self->notes('include_dirs'  => {});
        $self->notes('library_paths' => {});
        $self->notes(
            config => {
                FLTK_DATADIR => '',    # unused
                FLTK_DOCDIR  => '',    # unused
                BORDER_WIDTH => 2,     # 1.3
                WORDS_BIGENDIAN =>
                    ((unpack('h*', pack('s', 1)) =~ /01/) ? 1 : 0),    # both
                U16                    => undef,                       # both
                U32                    => undef,                       # both
                U64                    => undef,                       # both
                USE_X11                => undef,                       # both
                USE_QUARTZ             => undef,                       # both
                __APPLE_QUARTZ__       => undef,                       # 1.3.x
                __APPLE_QD__           => undef,                       # 1.3.x
                USE_COLORMAP           => 1,                           # both
                USE_X11_MULTITHREADING => 0,                           # 2.0
                USE_XFT                => 0,                           # both
                USE_XCURSOR            => undef,
                USE_CAIRO =>
                    ($self->notes('fltk_branch') eq '2.0.x' ? 0 : undef)
                ,                                                      # both
                USE_CLIPOUT      => 0,
                USE_XSHM         => 0,
                HAVE_XDBE        => 0,                                  # both
                USE_XDBE         => 'HAVE_XDBE',                        # both
                HAVE_OVERLAY     => 0,                                  # both
                USE_OVERLAY      => 0,
                USE_XINERAMA     => 0,
                USE_MULTIMONITOR => 1,
                USE_STOCK_BRUSH  => 1,
                USE_XIM          => 1,
                HAVE_ICONV       => 0,
                HAVE_GL          => (find_h('gl.h') ? 1 : undef),       # both
                HAVE_GL_GLU_H    => (find_h('gl/glu.h') ? 1 : undef),   # both
                HAVE_GL_OVERLAY  => 'HAVE_OVERLAY',                     # both
                USE_GL_OVERLAY   => 0,                                  # 2.0
                USE_GLEW         => 0,                                  # 2.0
                HAVE_GLXGETPROCADDRESSARB => undef,                     # 1.3
                HAVE_DIRENT_H => (find_h('dirent.h') ? 1 : undef),
                HAVE_STRING_H       => (find_h('string.h')       ? 1 : undef),
                HAVE_SYS_NSTRING_H  => (find_h('sys/ndir.h')     ? 1 : undef),
                HAVE_SYS_DIR_H      => (find_h('sys/dir.h')      ? 1 : undef),
                HAVE_NDIR_H         => (find_h('ndir.h')         ? 1 : undef),
                HAVE_SCANDIR        => 1,
                HAVE_SCANDIR_POSIX  => undef,
                HAVE_STRING_H       => (find_h('string.h')       ? 1 : undef),
                HAVE_STRINGS_H      => (find_h('strings.h')      ? 1 : undef),
                HAVE_VSNPRINTF      => 1,
                HAVE_SNPRINTF       => 1,
                HAVE_STRCASECMP     => undef,
                HAVE_STRDUP         => undef,
                HAVE_STRLCAT        => undef,
                HAVE_STRLCPY        => undef,
                HAVE_STRNCASECMP    => undef,
                HAVE_SYS_SELECT_H   => (find_h('sys/select.h')   ? 1 : undef),
                HAVE_SYS_STDTYPES_H => (find_h('sys/stdtypes.h') ? 1 : undef)
                ,    # both
                USE_POLL          => 0,                                 # both
                HAVE_LIBPNG       => undef,
                HAVE_LIBZ         => undef,
                HAVE_LIBJPEG      => undef,
                HAVE_LOCAL_PNG_H  => undef,
                HAVE_PNG_H        => undef,
                HAVE_LIBPNG_PNG_H => undef,
                HAVE_LOCAL_JPEG_H => undef,
                HAVE_PTHREAD      => undef,
                HAVE_PTHREAD_H    => (find_h('pthread.h') ? 1 : undef),
                HAVE_EXCEPTIONS   => undef,
                HAVE_DLOPEN       => 0,
                BOXX_OVERLAY_BUGS => 0,
                SGI320_BUG        => 0,
                CLICK_MOVES_FOCUS => 0,
                IGNORE_NUMLOCK    => 1,
                USE_PROGRESSIVE_DRAW => 1,
                HAVE_XINERAMA        => 0    # 1.3.x
            }
        );
        {
            print 'Locating library archiver... ';
            my $ar = can_run('ar');
            if (!$ar) {
                print "Could not find the library archiver, aborting.\n";
                exit 0;
            }
            $ar .= ' cr' . (can_run('ranlib') ? 's' : '');
            $self->notes(AR => $ar);
            print "$ar\n";
        }
        {
            my %sizeof;
            for my $type (qw[short int long]) {
                printf 'Checking size of %s... ', $type;
                my $exe = $self->build_exe({code => <<"" });
static long int longval () { return (long int) (sizeof ($type)); }
static unsigned long int ulongval () { return (long int) (sizeof ($type)); }
#include <stdio.h>
#include <stdlib.h>
int main ( ) {
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

                $sizeof{$type} = $exe ? `$exe` : 0;
                print "okay\n";
            }

            #
            if ($sizeof{'short'} == 2) {
                $self->notes('config')->{'U16'} = 'unsigned short';
            }
            if ($sizeof{'int'} == 4) {
                $self->notes('config')->{'U32'} = 'unsigned';
            }
            else {
                $self->notes('config')->{'U32'} = 'unsigned long';
            }
            if ($sizeof{'int'} == 8) {
                $self->notes('config')->{'U64'} = 'unsigned';
            }
            elsif ($sizeof{'long'} == 8) {
                $self->notes('config')->{'U64'} = 'unsigned long';
            }
            {
                print
                    'Checking whether the compiler recognizes bool as a built-in type... ';
                my $exe = $self->build_exe({code => <<"" });
#include <stdio.h>
#include <stdlib.h>
int f(int  x){printf ("int "); return 1;}
int f(char x){printf ("char"); return 1;}
int f(bool x){printf ("bool"); return 1;}
int main ( ) {
    bool b = true;
    return f(b);
}

                my $type = $exe ? `$exe` : 0;
                if ($type) { print "yes ($type)\n" }
                else {
                    print "no\n";    # But we can pretend...
                    $self->notes(  'cxxflags' => $self->notes('cxxflags')
                                 . ' -Dbool=char -Dfalse=0 -Dtrue=1 ');
                }
            }
            {
                print 'Checking for library containing pow... ';
                my $_have_pow = '';
            LIB: for my $lib ('', '-lm') {
                    my $exe = $self->build_exe(
                                  {code => <<'', extra_linker_flags => $lib});
#include <stdio.h>
#include <stdlib.h>
#ifdef __cplusplus
extern "C"
#endif
char pow ();
int main ( ) {
    printf ("1");
    return pow ();
    return 0;
}

                    if ($exe && `$exe`) {
                        if   ($lib) { print "$lib\n" }
                        else        { print "none required\n" }
                        $self->notes(
                             'ldflags' => $self->notes('ldflags') . " $lib ");
                        $_have_pow = 1;
                        last LIB;
                    }
                }
                if (!$_have_pow) {
                    print "FAIL!\n";    # XXX - quit
                }
            }
        }
        return 1;
    }
    {
        my %___LIBS = ();

        sub LIBS {
            my ($self) = @_;
            %___LIBS = (
                fltk2_images => {
                    directory => 'images',
                    source    => [
                        map { $_ . '.cxx' }
                            qw[FileIcon2 Fl_Guess_Image fl_jpeg fl_png
                            HelpDialog images_core pnmImage xpmFileImage]
                    ]
                },
                fltk2_z => {
                    directory => 'images/zlib',
                    source    => [
                        map { $_ . '.c' }
                            qw[adler32 compress crc32 gzio uncompr deflate
                            trees zutil inflate inftrees inffast infblock
                            infcodes infutil]
                    ]
                },
                fltk2_jpeg => {
                    directory => 'images/libjpeg',
                    source    => [
                        map { $_ . '.c' }
                            qw[jmemnobs jcapimin jcapistd jccoefct jccolor
                            jcdctmgr jchuff jcinit jcmainct jcmarker jcmaster
                            jcomapi jcparam jcphuff jcprepct jcsample jctrans
                            jdapimin jdapistd jdatadst jdatasrc jdcoefct
                            jdcolor jddctmgr jdhuff jdinput jdmainct jdmarker
                            jdmaster jdmerge jdphuff jdpostct jdsample jdtrans
                            jerror jfdctflt jfdctfst jfdctint jidctflt
                            jidctfst jidctint jidctred jquant1 jquant2 jutils
                            jmemmgr]
                    ]
                },
                fltk2_png => {
                    directory => 'images/libpng',
                    include   => 'zlib',
                    source    => [
                        map { $_ . '.c' }
                            qw[png pngset pngget pngrutil pngtrans pngwutil
                            pngread pngrio pngwio pngwrite pngrtran pngwtran
                            pngmem pngerror pngpread]
                    ]
                },
                fltk2 => {
                    directory => 'src',
                    source    => [
                        (map { $_ . '.c' } qw[scandir string utf vsnprintf]),
                        (  map { $_ . '.cxx' }
                               qw[add_idle addarc addcurve Adjuster AlignGroup
                               AnsiWidget args BarGroup bmpImage Browser
                               Browser_load Button CheckButton Choice clip
                               Clock Color color_chooser ComboBox compose
                               Cursor CycleButton default_glyph Dial
                               DiamondBox dnd drawtext EngravedLabel error
                               event_key_state file_chooser FileBrowser
                               FileChooser FileChooser2 FileIcon FileInput
                               filename_absolute filename_ext filename_isdir
                               filename_list filename_match filename_name
                               fillrect Fl_Menu_Item FloatInput fltk_theme
                               Font gifImage Group GSave HelpView
                               HighlightButton Image Input InputBrowser
                               InvisibleWidget Item key_name LightButton
                               list_fonts load_plugin lock Menu Menu_add
                               Menu_global Menu_popup MenuBar MenuWindow
                               message MultiImage NumericInput numericsort
                               Output OvalBox overlay_rect own_colormap
                               PackedGroup path PlasticBox PopupMenu
                               Preferences ProgressBar RadioButton readimage
                               RepeatButton ReturnButton RoundBox RoundedBox
                               run Scrollbar ScrollGroup scrollrect setcolor
                               setdisplay setvisual ShadowBox ShapedWindow
                               SharedImage ShortcutAssignment show_colormap
                               Slider StatusBarGroup StringList Style StyleSet
                               Symbol SystemMenuBar TabGroup TabGroup2
                               TextBuffer TextDisplay TextEditor ThumbWheel
                               TiledGroup TiledImage Tooltip UpBox Valuator
                               ValueInput ValueOutput ValueSlider Widget
                               Widget_draw WidgetAssociation Window
                               Window_fullscreen Window_hotspot Window_iconize
                               WizardGroup xbmImage xpmImage]
                        )
                    ]
                },
                fltk2_gl => {
                    directory => 'OpenGL',
                    source    => [
                        map { $_ . '.cxx' }
                            qw[Fl_Gl_Choice Fl_Gl_Overlay Fl_Gl_Window gl_draw
                            gl_start]
                    ]
                },
                fltk2_glut => {
                      directory => 'glut',
                      source    => [
                          map { $_ . '.cxx' } qw[glut_compatability glut_font]
                      ]
                },
                fltk => {
                    directory => 'src',
                    source    => [
                        (map { $_ . '.c' }
                             qw[fl_call_main flstring scandir numericsort
                             vsnprintf fl_utf]
                        ),
                        (map { $_ . '.cxx' } 'Fl',
                         'screen_xywh',
                         (map { 'Fl_' . $_ }
                              qw[Adjuster Bitmap Browser Browser_
                              Browser_load Box Button Chart Check_Browser
                              Check_Button Choice Clock Color_Chooser
                              Counter Dial Double_Window File_Browser
                              File_Chooser File_Chooser2 File_Icon
                              File_Input Group Help_View Image Input Input_
                              Light_Button Menu Menu_ Menu_Bar Sys_Menu_Bar
                              Menu_Button Menu_Window Menu_add Menu_global
                              Multi_Label Overlay_Window Pack Pixmap
                              Positioner Preferences Progress Repeat_Button
                              Return_Button Roller Round_Button Scroll
                              Scrollbar Shared_Image Single_Window Slider
                              Table Table_Row Tabs Text_Buffer Text_Display
                              Text_Editor Tile Tiled_Image Tree Tree_Item
                              Tree_Item_Array Tree_Prefs Tooltip Valuator
                              Value_Input Value_Output Value_Slider Widget
                              Window Window_fullscreen Window_hotspot
                              Window_iconize Wizard XBM_Image XPM_Image
                              abort add_idle arg compose display get_key
                              get_system_colors grab lock own_colormap
                              visual x]
                         ),
                         (map { 'filename_' . $_ }
                              qw[absolute expand ext isdir list match setext]
                         ),
                         (map { 'fl_' . $_ }
                              qw[arc arci ask boxtype color cursor curve
                              diamond_box dnd draw draw_image draw_pixmap
                              encoding_latin1 encoding_mac_roman
                              engraved_label file_dir font gtk labeltype
                              line_style open_uri oval_box overlay
                              overlay_visual plastic read_image rect
                              round_box rounded_box set_font set_fonts
                              scroll_area shadow_box shortcut show_colormap
                              symbols vertex utf8]
                         )
                        ),
                        (map { 'xutf8/' . $_ . '.c' }
                             qw[case is_right2left is_spacing keysym2Ucs
                             utf8Input utf8Utils utf8Wrap]
                        ),
                    ]
                },
                fltk_forms => {
                    directory => 'src',
                    source    => [
                        map { 'forms_' . $_ . '.cxx' }
                            qw[compatability bitmap free fselect pixmap timer]
                    ]
                },
                fltk_gl => {
                    directory => 'src',
                    source    => [
                        map { $_ . '.cxx' }
                            qw[Fl_Gl_Choice Fl_Gl_Overlay Fl_Gl_Window
                            freeglut_geometry freeglut_stroke_mono_roman
                            freeglut_stroke_roman freeglut_teapot gl_draw
                            gl_start glut_compatability glut_font]
                    ]
                },
                fltk_image => {
                    directory => 'src',
                    source    => [
                        map { $_ . '.cxx' }
                            qw[fl_images_core Fl_BMP_Image Fl_File_Icon2
                            Fl_GIF_Image Fl_Help_Dialog Fl_JPEG_Image
                            Fl_PNG_Image Fl_PNM_Image]
                    ]
                }
            ) if !keys %___LIBS;
            return \%___LIBS;
        }
    }

    sub build_fltk {
        my ($self, $build) = @_;
        $self->quiet(1);
        my (@lib, @_libs);
        if ($self->notes('fltk_branch') eq '1.3.x') {
            @_libs = grep { $_ !~ m[2] } keys %{$self->LIBS};
        }
        elsif ($self->notes('fltk_branch') eq '2.0.x') {
            @_libs = grep { $_ =~ m[2] } keys %{$self->LIBS};
        }
        for my $lib (sort { lc $a cmp lc $b } @_libs) {
            print "Building $lib...\n";
            if (!chdir _dir($build->fltk_dir(),
                            $self->LIBS->{$lib}{'directory'}))
            {   printf 'Cannot chdir to %s',
                    _dir($build->fltk_dir(),
                         $self->LIBS->{$lib}{'directory'});
                exit 0;
            }
            my @obj;
            for my $src (@{$self->LIBS->{$lib}{'source'}}) {
                my $obj = _o($src);
                $obj
                    = $build->up_to_date($src, $obj)
                    ? $obj
                    : sub {
                    print "Compiling $src...\n";
                    return
                        $self->compile(
                        {source       => $src,
                         include_dirs => [
                             $Config{'incpath'},
                             '.',
                             _rel($build->fltk_dir($build)),
                             _rel($build->fltk_dir($build) . '/fltk/compat/'),
                             _rel($build->fltk_dir($build)
                                      . (
                                        $self->notes('fltk_branch') eq '1.3.x'
                                        ? ''
                                        : '/images'
                                      )
                                      . '/zlib/'
                             ),
                             (keys %{$self->notes('include_dirs')})
                         ],
                         cxxflags => [$Config{'ccflags'}],
                         output   => $obj
                        }
                        );
                    }
                    ->();
                if (!$obj) {
                    printf 'Failed to compile %s', $src;
                    exit 0;
                }
                push @obj, $obj;
            }
            my $_lib = _rel(_dir($build->fltk_dir, 'lib', _a($lib)));
            $lib
                = $build->up_to_date(\@obj, $_lib)
                ? $_lib
                : $self->archive({output  => $_lib,
                                  objects => \@obj
                                 }
                );
            if (!$lib) {
                printf 'Failed to create %s library', $lib;
                exit 0;
            }
            push @lib, _abs($lib);
        }
        if (!chdir $build->fltk_dir($self)) {
            print 'Failed to cd to ' . $self->fltk_dir();
            exit 0;
        }
        $self->quiet(0);
        return @lib ? 1 : 0;
    }

    # Module::Build actions
    sub ACTION_fetch_fltk {
        my ($self) = @_;
        my %mirrors = (
                'ftp.easysw.com'  => 'California, USA',
                'ftp2.easysw.com' => 'New Jersey, USA',
                'ftp.funet.fi/pub/mirrors/ftp.easysw.com' => 'Espoo, Finland',
                'ftp.rz.tu-bs.de/pub/mirror/ftp.easysw.com/ftp' =>
                    'Braunschweig, Germany'
        );
        my $dest = 'snapshots';
        $self->notes('archive_path' =>
                         _abs(_dir(sprintf('snapshots/fltk-%s-r%s.tar.gz',
                                           $self->notes('fltk_branch'),
                                           $self->notes('fltk_svn')
                                   )
                              )
                         )
        );
        return if -f $self->notes('archive_path');
        require File::Fetch;
        my $path;
    MIRROR: for my $mirror (keys %mirrors) {

            for my $prot (qw[ftp http]) {
                my $from
                    = sprintf '%s://%s/pub/fltk/snapshots/fltk-%s-r%s.tar.gz',
                    $prot, $mirror,
                    $self->notes('fltk_branch'),
                    $self->notes('fltk_svn');
                printf
                    "Fetching r%s from the %s branch of fltk from %s mirror\n    %s...\n",
                    $self->notes('fltk_svn'), $self->notes('fltk_branch'),
                    $mirrors{$mirror}, $from;
                $path = File::Fetch->new(uri => $from)->fetch(to => $dest);

                # XXX - verify with md5
                last MIRROR if $path;
            }
        }
        if (!$path) {
            my $msg = sprintf <<'END',
We failed to fetch fltk-%s-r%s.tar.gz.

If this problem persists, you may download the archive yourself and put it in
the ./%s/ directory. Alien::FLTK will attempt to extract and build the libs
from there.

Use any of these mirrors:

END
                $self->notes('fltk_branch'), $self->notes('fltk_svn'), $dest;
            for my $mirror (keys %mirrors) {
                $msg .= " " x 4 . $mirrors{$mirror} . "\n";
                for my $prot (qw[ftp http]) {
                    $msg .= sprintf
                        "      %s://%s/pub/fltk/snapshots/fltk-%s-r%s.tar.gz\n",
                        $prot, $mirror, $self->notes('fltk_branch'),
                        $self->notes('fltk_svn');
                }
            }
            push @{$self->notes('errors')},
                {stage   => 'fltk source download',
                 fatal   => 1,
                 message => $msg
                };
            return;
        }
        return $path;
    }

    sub ACTION_extract_fltk {
        my ($self) = @_;
        $self->depends_on('fetch_fltk');
        my $archive = $self->notes('archive_path');
        return 1 if -d _dir($self->fltk_dir());
        printf 'Extracting fltk source from %s... ', _rel($archive);
        require Archive::Extract;
        my $ae = Archive::Extract->new(archive => $archive);
        if (!$ae->extract(to => 'src')) {
            push @{$self->notes('errors')},
                {stage   => 'fltk source extraction',
                 fatal   => 1,
                 message => $ae->error
                };
            return;
        }
        print "okay\n";
        return 1;
    }

    sub ACTION_configure_fltk {
        my ($self) = @_;
        $self->depends_on('fetch_fltk');
        $self->depends_on('extract_fltk');

        #if (!$self->notes('config') || !keys %{$self->notes('config')}) {
        if (   !$self->notes('config')
            || !-f $self->fltk_dir() . '/config.h')
        {   print "Gathering configuration data...\n";
            $self->configure();
            $self->notes(timestamp_configure => time);
        }
        return 1;
    }

    sub ACTION_write_config_h {
        my ($self) = @_;
        $self->depends_on('fetch_fltk');
        $self->depends_on('extract_fltk');
        $self->depends_on('configure_fltk');
        if (!chdir $self->fltk_dir()) {
            print 'Failed to cd to ' . $self->fltk_dir();
            exit 0;
        }
        if (   (!-f 'config.h')
            || (!$self->notes('timestamp_config_h'))
            || ($self->notes('timestamp_configure')
                > $self->notes('timestamp_config_h'))
            )
        {   {
                print 'Creating config.h... ';
                if (!chdir $self->fltk_dir()) {
                    print 'Failed to cd to ' . $self->fltk_dir();
                    exit 0;
                }
                my $config = '';
                my %config = %{$self->notes('config')};
                for my $key (
                    sort {
                        $config{$a} && $config{$a} =~ m[^HAVE_]
                            ? ($b cmp $a)
                            : ($a cmp $b)
                    } keys %config
                    )
                {   $config .=
                        sprintf((defined $config{$key}
                                 ? '#define %-25s %s'
                                 : '#undef  %-35s'
                                )
                                . "\n",
                                $key,
                                $config{$key}
                        );
                }
                $config .= "\n";
                open(my $CONFIG_H, '>', 'config.h')
                    || Carp::confess 'Failed to open config.h ';
                syswrite($CONFIG_H, $config) == length($config)
                    || Carp::confess 'Failed to write config.h';
                close $CONFIG_H;
                if (!chdir $self->base_dir()) {
                    print 'Failed to cd to base directory';
                    exit 0;
                }
                $self->notes(timestamp_config_h => time);
                print "okay\n";
            }
        }
        {    # Ganked from Module::Build::Notes
            print 'Updating Alien::FLTK config... ';
            my $me = _abs($self->base_dir() . '/lib/Alien/FLTK.pm');
            require IO::File;
            my $mode_orig = (stat $me)[2] & 07777;
            chmod($mode_orig | 0222, $me);    # Make it writeable
            my $fh = IO::File->new($me, 'r+')
                or die "Can't rewrite $me: $!";
            seek($fh, 0, 0);
            while (<$fh>) { last if /^__DATA__$/; }

            if (eof($fh)) {    #warn "Couldn't find __DATA__ token in $me";
                $fh->print("\n__DATA__\n");
            }
            seek($fh, tell($fh), 0);
            my $data = $self->notes();
            if (eval 'require Data::Dump') {
                $fh->print(sprintf 'do{ my $x = %s; $x; }' . "\n",
                           Data::Dump::pp($data));
            }
            else {
                require Data::Dumper;
                my $Dumper = Data::Dumper->new([$data], ['x']);
                $Dumper->Purity(1);
                $fh->print(sprintf 'do{ my %s; $x; }' . "\n",
                           $Dumper->Dump());
            }
            truncate($fh, tell($fh));
            $fh->close;
            chmod($mode_orig, $me)
                or warn "Couldn't restore permissions on $me: $!";
            print "okay\n";
        }
        if (!chdir $self->base_dir()) {
            print 'Failed to cd to base directory';
            exit 0;
        }
        return 1;
    }

    sub ACTION_clear_config {
        my ($self) = @_;
        print 'Cleaning Alien::FLTK config... ';
        my $me = _abs($self->base_dir() . '/lib/Alien/FLTK.pm');
        require IO::File;
        my $mode_orig = (stat $me)[2] & 07777;
        chmod($mode_orig | 0222, $me);    # Make it writeable
        my $fh = IO::File->new($me, 'r+')
            or die "Can't rewrite $me: $!";
        seek($fh, 0, 0);
        while (<$fh>) { last if /^__DATA__$/; }
        die "Couldn't find __DATA__ token in $me" if eof($fh);
        seek($fh, tell($fh), 0);
        $fh->print("do{ my \$x = { }; \$x; }\n");
        truncate($fh, tell($fh));
        $fh->close;
        chmod($mode_orig, $me)
            or warn "Couldn't restore permissions on $me: $!";
        print "okay\n";
    }

    sub ACTION_build_fltk {
        my ($self) = @_;
        $self->depends_on('fetch_fltk');
        $self->depends_on('extract_fltk');
        $self->depends_on('configure_fltk');
        $self->depends_on('write_config_h');
        if (!chdir $self->fltk_dir()) {
            printf 'Failed to cd to %s to locate libs libs',
                $self->fltk_dir();
            exit 0;
        }
        my @lib = $self->build_fltk($self);
        if (!chdir $self->base_dir()) {
            printf 'Failed to return to %s to copy libs', $self->base_dir();
            exit 0;
        }
        if (!chdir _dir($self->fltk_dir() . '/lib')) {
            printf 'Failed to cd to %s to copy libs', $self->fltk_dir();
            exit 0;
        }
        $self->copy_if_modified(from => $_,
                                to_dir =>
                                    _dir($self->base_dir(),
                                         qw[blib arch Alien FLTK libs],
                                         'fltk-' . $self->notes('fltk_branch')
                                    )
            )
            for grep defined, map { my $_a = _a($_); -f $_a ? $_a : () } (
            $self->notes('fltk_branch') eq '1.3.x' ? (
               qw?fltk     fltk_gl   fltk_glut fltk_forms
                   fltk_images fltk_jpeg fltk_png  fltk_z?
                )
            : (qw?fltk2     fltk2_gl   fltk2_glut fltk2_forms
                   fltk2_images fltk2_jpeg fltk2_png  fltk2_z?
            )
            );
        if (!chdir $self->base_dir()) {
            print 'Failed to cd to base directory';
            exit 0;
        }
        return 1;
    }

    sub ACTION_code {
        my ($self) = @_;
        for my $action (
            qw[fetch_fltk extract_fltk configure_fltk write_config_h build_fltk
            copy_headers])
        {   $self->depends_on($action);
            $self->dispatch('check_errors');
        }
        return $self->SUPER::ACTION_code;
    }

    sub ACTION_check_errors {
        my ($self) = @_;
        return if !@{$self->notes('errors')};
        my $fatal = 0;
        for my $error (@{$self->notes('errors')}) {
            next if $error->{'seen'}++ && !$error->{'fatal'};
            $fatal += $error->{'fatal'};
            my $msg = $error->{'message'};
            $msg =~ s|(.+)|  $1|gm;
            printf "\nWARNING: %s error enountered during %s:\n%s\n",
                ($error->{'fatal'} ? ('*** Fatal') : 'Non-fatal'),
                $error->{'stage'}, $msg, '-- ' x 10;
        }
        if ($fatal) {
            printf STDOUT ('*** ' x 15) . "\n"
                . '%s fatal error%s encountered during the build process. '
                . "Please correct %s and run Build.PL again.\nExiting...",
                $fatal == 1
                ? ('A', ' was', 'it')
                : ($fatal, 's were', 'them');
            exit 0;
        }
    }

    sub ACTION_clean {
        my $self = shift;
        $self->dispatch('clear_config');
        $self->SUPER::ACTION_clean(@_);
        $self->notes(errors => []);    # Reset fatal and non-fatal errors
    }
    {

        # Ganked from Devel::CheckLib
        sub assert_lib {
            my ($self, $args) = @_;
            my (@libs, @libpaths, @headers, @incpaths);

            # FIXME: these four just SCREAM "refactor" at me
            @libs = (ref($args->{'lib'}) ? @{$args->{'lib'}} : $args->{'lib'})
                if $args->{'lib'};
            @libpaths = (ref($args->{'libpath'})
                         ? @{$args->{'libpath'}}
                         : $args->{'libpath'}
            ) if $args->{'libpath'};
            @headers = (ref($args->{'header'})
                        ? @{$args->{'header'}}
                        : $args->{'header'}
            ) if $args->{'header'};
            @incpaths = (ref($args->{'incpath'})
                         ? @{$args->{'incpath'}}
                         : $args->{'incpath'}
            ) if $args->{'incpath'};
            my @missing;

            # first figure out which headers we can't find ...
            for my $header (@headers) {
                my $exe =
                    $self->build_exe(
                    {code =>
                         "#include <$header>\nint main(void) { return 0; }\n",
                     include_dirs => \@incpaths,
                     lib_dirs     => \@libpaths
                    }
                    );
                if   (defined $exe && -x $exe) { unlink $exe }
                else                           { push @missing, $header }
            }

            # now do each library in turn with no headers
            for my $lib (@libs) {
                my $exe =
                    $self->build_exe(
                                    {code => "int main(void) { return 0; }\n",
                                     include_dirs       => \@incpaths,
                                     lib_dirs           => \@libpaths,
                                     extra_linker_flags => "-l$lib"
                                    }
                    );
                if   (defined $exe && -x $exe) { unlink $exe }
                else                           { push @missing, $lib }
            }
            my $miss_string = join(q{, }, map {qq{'$_'}} @missing);
            if (@missing) {
                warn "Can't link/include $miss_string\n";
                return 0;
            }
            return 1;
        }
    }
    1;
}

=pod

=head1 FLTK 1.3.x Configuration Options

=head2 C<BORDER_WIDTH>

Thickness of C<FL_UP_BOX> and C<FL_DOWN_BOX>.  Current C<1,2,> and C<3> are
supported.

  3 is the historic FLTK look.
  2 is the default and looks (nothing) like Microsoft Windows, KDE, and Qt.
  1 is a plausible future evolution...

Note that this may be simulated at runtime by redefining the boxtypes using
C<Fl::set_boxtype()>.

=head1 FLTK 2.0.x Configuration Options

TODO

=cut
