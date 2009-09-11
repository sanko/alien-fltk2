package MBX::Alien::FLTK::Base;
{
    use strict;
    use warnings;
    use Cwd;
    use Config qw[%Config];
    use File::Temp qw[tempfile];
    use File::Spec::Functions qw[rel2abs abs2rel];
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
                   rel2abs(sprintf '%s/src/fltk-2.0.x-r%d', $self->base_dir(),
                           $self->notes('fltk_svn')
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
        File::Spec->catfile($self->install_destination('arch'),
                            qw[Alien FLTK], File::Spec->splitdir($dir),
                            $file);
    }

    sub copy_headers {
        my ($self) = @_;
        if (!chdir _dir($self->fltk_dir() . '/fltk')) {
            print 'Failed to cd to fltk\'s include directory';
            exit 0;
        }
        my $top = $self->base_dir();
        find {
            wanted => sub {
                return if -d;
                $self->copy_if_modified(
                               from => $File::Find::name,
                               to   => rel2abs(
                                         $top
                                       . '/blib/arch/Alien/FLTK/include/fltk/'
                                       . $File::Find::name
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
        $self->copy_if_modified(
             from => 'config.h',
             to =>
                 rel2abs($top . '/blib/arch/Alien/FLTK/include/fltk/config.h')
        );
        print "Installing FLTK2.x and FLTK1.1 emulation headers...\n";
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
        $self->notes('ldflags'  => ' -lfltk2 ');
        $self->notes('cxxflags' => ' ');
        $self->notes('GL'       => ' ');
        $self->notes('image_flags' =>
            ' -lfltk2_images -lfltk2_png -lfltk2_z -lfltk2_images -lfltk2_jpeg '
        );
        $self->notes('include_dirs'  => {});
        $self->notes('library_paths' => {});
        $self->notes(
            config => {
                FLTK_DATADIR => '',    # unused
                FLTK_DOCDIR  => '',    # unused
                WORDS_BIGENDIAN =>
                    ((unpack('h*', pack('s', 1)) =~ /01/) ? 1 : undef),
                U16                    => undef,
                U32                    => undef,
                U64                    => undef,
                USE_X11                => undef,
                USE_QUARTZ             => undef,
                USE_COLORMAP           => 1,
                USE_X11_MULTITHREADING => 0,
                USE_XFT                => 0,
                USE_XCURSOR            => undef,
                USE_CAIRO              => 0,
                USE_CLIPOUT            => 0,
                USE_XSHM               => 0,
                HAVE_XDBE              => 0,
                USE_XDBE               => 'HAVE_XDBE',
                HAVE_OVERLAY           => 0,
                USE_OVERLAY            => 0,
                USE_XINERAMA           => 0,
                USE_MULTIMONITOR       => 1,
                USE_STOCK_BRUSH        => 1,
                USE_XIM                => 1,
                HAVE_ICONV             => 0,
                HAVE_GL                => (find_h('gl.h') ? 1 : undef),
                HAVE_GL_GLU_H          => (find_h('gl/glu.h') ? 1 : undef),
                HAVE_GL_OVERLAY        => 'HAVE_OVERLAY',
                USE_GL_OVERLAY         => 0,
                USE_GLEW               => 0,
                HAVE_DIRENT_H          => (find_h('dirent.h') ? 1 : undef),
                HAVE_STRING_H          => (find_h('string.h') ? 1 : undef),
                HAVE_SYS_NSTRING_H     => (find_h('sys/ndir.h') ? 1 : undef),
                HAVE_SYS_DIR_H         => (find_h('sys/dir.h') ? 1 : undef),
                HAVE_NDIR_H            => (find_h('ndir.h') ? 1 : undef),
                HAVE_SCANDIR           => 1,
                HAVE_SCANDIR_POSIX     => undef,
                HAVE_STRING_H          => (find_h('string.h') ? 1 : undef),
                HAVE_STRINGS_H         => (find_h('strings.h') ? 1 : undef),
                HAVE_VSNPRINTF         => 1,
                HAVE_SNPRINTF          => 1,
                HAVE_STRCASECMP        => undef,
                HAVE_STRDUP            => undef,
                HAVE_STRLCAT           => undef,
                HAVE_STRLCPY           => undef,
                HAVE_STRNCASECMP       => undef,
                HAVE_SYS_SELECT_H => (find_h('sys/select.h') ? 1 : undef),
                HAVE_SYS_STDTYPES_H => (find_h('sys/stdtypes.h') ? 1 : undef),
                USE_POLL            => 0,
                HAVE_LIBPNG         => undef,
                HAVE_LIBZ           => undef,
                HAVE_LIBJPEG        => undef,
                HAVE_LOCAL_PNG_H    => undef,
                HAVE_PNG_H          => undef,
                HAVE_LIBPNG_PNG_H   => undef,
                HAVE_LOCAL_JPEG_H   => undef,
                HAVE_PTHREAD        => undef,
                HAVE_PTHREAD_H      => (find_h('pthread.h')      ? 1 : undef),
                HAVE_EXCEPTIONS     => undef,
                HAVE_DLOPEN         => 0,
                BOXX_OVERLAY_BUGS   => 0,
                SGI320_BUG          => 0,
                CLICK_MOVES_FOCUS   => 0,
                IGNORE_NUMLOCK      => 1,
                USE_PROGRESSIVE_DRAW => 1
            }
        );
        {
            $self->notes('include_dirs')->{rel2abs($self->fltk_dir())}++;
        }
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
                        print($lib ? "$lib\n" : "none required\n");
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
        print "Building fltk2 libs...\n";
        for my $dir (sort { lc $a cmp lc $b } keys %LIBS) {
            if (!chdir $build->base_dir()) {
                print '...you can\'t go home again.';
                exit 0;
            }
            if (!chdir $build->fltk_dir() . "/$dir") {
                print 'Cannot chdir to ' . $build->fltk_dir() . '/' . $dir;
                exit 0;
            }
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
                                include_dirs => [
                                        $Config{'incpath'},
                                        '.',
                                        _rel($build->fltk_dir($build)),
                                        _rel($build->fltk_dir($build)
                                                 . '/fltk/compat/'
                                        ),
                                        _rel($build->fltk_dir($build)
                                                 . '/images/zlib/'
                                        ),
                                        (keys %{$self->notes('include_dirs')})
                                ],
                                verbose  => $build->VERBOSE(),
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
                                      objects => \@obj,
                                      verbose => $build->VERBOSE()
                                     }
                    );
                if (!$lib) {
                    printf 'Failed to create %s library', $lib;
                    exit 0;
                }
                push @lib, _abs($lib);
            }
        }
        if (!chdir $build->fltk_dir($self)) {
            print 'Failed to cd to fltk\'s base directory';
            exit 0;
        }
        return @lib ? 1 : 0;
    }

    # Module::Build actions
    sub ACTION_fetch_fltk2 {
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
                         rel2abs(      'snapshots/fltk-2.0.x-r'
                                     . $self->notes('fltk_svn')
                                     . '.tar.gz'
                         )
        );
        return if -f $self->notes('archive_path');
        require File::Fetch;
        my $path;
    MIRROR: for my $mirror (keys %mirrors) {

            for my $prot (qw[ftp http]) {
                my $from
                    = sprintf
                    '%s://%s/pub/fltk/snapshots/fltk-2.0.x-r%s.tar.gz',
                    $prot, $mirror, $self->notes('fltk_svn');
                printf
                    "Fetching FLTK 2.0.x source from %s mirror\n    %s...\n",
                    $mirrors{$mirror}, $from;
                $path = File::Fetch->new(uri => $from)->fetch(to => $dest);

                # XXX - verify with md5
                last MIRROR if $path;
            }
        }
        if (!$path) {
            printf <<'END', $self->notes('fltk_svn'), $dest;
 --- --- --- --- --- --- --- --- --- --- --- --- --- --- --- --- --- --- ---
       ERROR: We failed to fetch fltk-2.0.x-r%s.tar.gz and will exit.

  If this problem persists, you may download the archive yourself and put
  it in the ./%s/ directory. Alien::FLTK will attempt to extract and build
  the libs from there.

  Use any of these mirrors:

END
            for my $mirror (keys %mirrors) {
                print " " x 4 . $mirrors{$mirror} . "\n";
                for my $prot (qw[ftp http]) {
                    printf
                        "      %s://%s/pub/fltk/snapshots/fltk-2.0.x-r%s.tar.gz\n",
                        $prot, $mirror, $self->notes('fltk_svn');
                }
            }
            print ' ---' x 19;
            exit 0;    # Clean exit
        }
        return $path;
    }

    sub ACTION_extract_fltk2 {
        my ($self) = @_;
        $self->depends_on('fetch_fltk2');
        my $archive = $self->notes('archive_path');
        return 1 if -d _dir($self->fltk_dir());
        printf 'Extracting fltk2 source from %s... ', _rel($archive);
        require Archive::Extract;
        my $ae = Archive::Extract->new(archive => $archive);
        if (!$ae->extract(to => 'src')) {
            carp "\nError: " . $ae->error;
            return 0;
        }
        print "okay\n";
        return 1;
    }

    sub ACTION_configure_fltk2 {
        my ($self) = @_;
        $self->depends_on('fetch_fltk2');
        $self->depends_on('extract_fltk2');

        #if (!$self->notes('config') || !keys %{$self->notes('config')}) {
        if (!$self->notes('config') || !-f $self->fltk_dir() . '/config.h') {
            print "Gathering configuration data...\n";
            $self->configure();
            $self->notes(timestamp_configure => time);
        }
        return 1;
    }

    sub ACTION_write_config_h {
        my ($self) = @_;
        $self->depends_on('fetch_fltk2');
        $self->depends_on('extract_fltk2');
        $self->depends_on('configure_fltk2');
        if (!chdir $self->fltk_dir()) {
            print 'Failed to cd to fltk\'s base directory';
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
                    print 'Failed to cd to fltk\'s base directory';
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
            {    # Ganked from Module::Build::Notes
                print 'Updating Alien::FLTK config... ';
                my $me = rel2abs($self->base_dir() . '/lib/Alien/FLTK.pm');
                require IO::File;
                my $mode_orig = (stat $me)[2] & 07777;
                chmod($mode_orig | 0222, $me);    # Make it writeable
                my $fh = IO::File->new($me, 'r+')
                    or die "Can't rewrite $me: $!";
                seek($fh, 0, 0);
                while (<$fh>) { last if /^__DATA__$/; }

                if (eof($fh)) {
                    #warn "Couldn't find __DATA__ token in $me";
                    $fh->print("\n__DATA__\n");
                }
                seek($fh, tell($fh), 0);
                my $data = $self->notes();
                if (eval 'require Data::Dump') {
                    $fh->print(  'do{ my $x = '
                               . Data::Dump::pp($data)
                               . "; \$x; }\n");
                }
                else {
                    require Data::Dumper;
                    $fh->print('do{ my '
                               . Data::Dumper->new([$data], ['x'])->Purity(1)
                               ->Dump()
                               . "\$x; }\n");
                }
                truncate($fh, tell($fh));
                $fh->close;
                chmod($mode_orig, $me)
                    or warn "Couldn't restore permissions on $me: $!";
                print "okay\n";
            }
        }
        if (!chdir $self->base_dir()) {
            print 'Failed to cd to base directory';
            exit 0;
        }
        return 1;
    }

    sub ACTION_build_fltk2 {
        my ($self) = @_;
        $self->depends_on('fetch_fltk2');
        $self->depends_on('extract_fltk2');
        $self->depends_on('configure_fltk2');
        $self->depends_on('write_config_h');
        if (!chdir $self->fltk_dir()) {
            print 'Failed to cd to fltk\'s base directory';
            exit 0;
        }
        my @lib = $self->build_fltk($self);
        if (!chdir $self->base_dir()) {
            printf 'Failed to return to %s', $self->base_dir();
            exit 0;
        }
        if (!chdir _dir($self->fltk_dir() . '/lib')) {
            print 'Failed to cd to fltk\'s base directory';
            exit 0;
        }
        $self->copy_if_modified(
              from   => $_,
              to_dir => _dir($self->base_dir() . '/blib/arch/Alien/FLTK/libs')
            )
            for grep defined,
            map { my $_a = _a($_); -f $_a ? $_a : () }
            qw;
            fltk2        fltk2_gl   fltk2_glut  fltk2_forms
            fltk2_images fltk2_jpeg fltk2_png   fltk2_z;;
        if (!chdir $self->base_dir()) {
            print 'Failed to cd to base directory';
            exit 0;
        }
        return 1;
    }

    sub ACTION_code {
        my ($self) = @_;
        $self->depends_on('fetch_fltk2');
        $self->depends_on('extract_fltk2');
        $self->depends_on('configure_fltk2');
        $self->depends_on('write_config_h');
        $self->depends_on('build_fltk2');
        $self->copy_headers();    # XXX - part of build_fltk2
        return $self->SUPER::ACTION_code;
    }
    {

        # Ganked from Devel::CheckLib
        sub assert_lib {
            my ($self, %args) = @_;
            my (@libs, @libpaths, @headers, @incpaths);

            # FIXME: these four just SCREAM "refactor" at me
            @libs = (ref($args{lib}) ? @{$args{lib}} : $args{lib})
                if $args{lib};
            @libpaths
                = (ref($args{libpath}) ? @{$args{libpath}} : $args{libpath})
                if $args{libpath};
            @headers = (ref($args{header}) ? @{$args{header}} : $args{header})
                if $args{header};
            @incpaths
                = (ref($args{incpath}) ? @{$args{incpath}} : $args{incpath})
                if $args{incpath};
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
                push @missing, $header if !-x $exe;
                unlink $exe;
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
                push @missing, $lib if !-x $exe;
                unlink $exe;
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
