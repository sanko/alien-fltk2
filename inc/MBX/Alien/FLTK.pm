package MBX::Alien::FLTK;
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
    use lib qw[inc ..];
    use MBX::Alien::FLTK::Utility qw[_o _a _dir _file _exe];

    sub new {
        my ($class, %args) = @_;
        shift;
        my $self = $class->SUPER::new(@_);
        $self->_find_compiler();
        return $self;
    }

    sub resume {
        my $self = shift->SUPER::resume(@_);
        $self->_find_compiler(@_);
        return $self;
    }
    sub VERBOSE { shift->notes('verbose') }

    sub _find_compiler {
        my ($self, %args) = @_;
        my $OS = $args{'osname'} || $Config{'osname'} || $^O;
        my $CC = $args{'cc'}     || $Config{'ccname'} || $Config{'cc'};
        my $type = sprintf 'MBX::Alien::FLTK::%s%s', $OS =~ m[Win32]
            ? (
            'Win32',
            ($CC =~ m[gcc]i
             ? '::MinGW'
             : $CC =~ m[cl]i    ? '::MSVC'       # TODO - use proj files?
             : $CC =~ m[bcc32]i ? '::Borland'    # TODO
             : $CC =~ m[icl]i   ? '::Intel'      # TODO
             : ''
            )
            )
            : $OS =~ m[MacOS]i ? ('MacOS', '')    # TODO
            :                    ('Unix',  '');
        my $compiler;
        eval "use $type;\$compiler = $type->new();";
        if ($@ || !$compiler) {
            carp <<'' . $@ if $self->VERBOSE;
Your system/compiler combination may not be supported. Using defaults.
  Actual error message follows:

            $compiler = $self;                    # Meh?
        }
        return $self->{'stash'}{'_compiler'} = $compiler;   # MB is hash based
    }

    sub ACTION_install {    # TODO: update config data for final destination
        my $self = shift;
        $self->SUPER::ACTION_install;
    }

    sub ACTION_code {
        my ($self) = @_;
        $self->depends_on('fetch_fltk2');
        $self->depends_on('extract_fltk2');
        $self->depends_on('configure_fltk2');
        $self->depends_on('build_fltk2');
        $self->copy_headers();    # XXX - part of build_fltk2
        return $self->SUPER::ACTION_code;
    }

    sub ACTION_configure_fltk2 {  # XXX - if!(-f'config.h'&&-f'config.status')
        my ($self) = @_;
        chdir $self->fltk_dir()
            or die sprintf 'failed to cd to %s: %s' , $self->fltk_dir(), $!;
        if (!-f _dir($self->fltk_dir() . '/config.h')) {
            print 'Creating config.h...';
            chdir($self->fltk_dir())
                || Carp::confess 'Failed to chdir to ' . $self->fltk_dir();
            $self->{'stash'}{'_compiler'}->configure($self);
        }
        chdir $self->base_dir() || die q[You can't go home again!];
    }

    sub ACTION_build_fltk2 {
        my ($self) = @_;
        chdir $self->fltk_dir()
            or die q[failed to cd to fltk's base directory];
        my @lib = $self->{'stash'}{'_compiler'}->build_fltk($self);
        die sprintf 'Failed to return to %s', $self->base_dir()
            if !chdir $self->base_dir();
        chdir _dir($self->fltk_dir() . '/lib')
            or die q[failed to cd to fltk's base directory];
        $self->copy_if_modified(
              from   => $_,
              to_dir => _dir($self->base_dir() . '/blib/arch/Alien/FLTK/libs')
            )
            for grep defined,
            map { my $_a = _a($_); -f $_a ? $_a : () }
            qw;
            fltk2        fltk2_gl   fltk2_glut  fltk2_forms
            fltk2_images fltk2_jpeg fltk2_png   fltk2_z;;
        $self->notes('~libs'      => \@lib);
        $self->notes(libs         => [map { _file($_) } @lib]);
        $self->notes(library_path => $self->_archdir('libs'));
        $self->notes(
               'fltk2-config' => {
                   cflags   => $self->{'stash'}{'_compiler'}->cflags($self),
                   cxxflags => $self->{'stash'}{'_compiler'}->cxxflags($self),
                   ldflags  => $self->{'stash'}{'_compiler'}->ldflags($self),
               }
        );
        chdir $self->base_dir() || die q[You can't go home again!];
        return 1;
    }

    sub copy_headers {
        my ($self) = @_;
        chdir _dir($self->fltk_dir() . '/fltk')
            or die q[failed to cd to fltk's include directory];
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
        print
            "Installing FLTK2.x includes and FLTK1.1 emulation includes...\n";
        die sprintf 'Failed to return to %s', $self->base_dir()
            if !chdir $self->base_dir();
        $self->notes(include_path => $self->_archdir('include'));
        return 1;
    }

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
            for my $prot (qw[ ftp http]) {
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
        die 'Unable to fetch archive' unless $path;
        return $path;
    }

    sub ACTION_extract_fltk2 {
        my ($self) = @_;
        my $archive = $self->notes('archive_path');
        return 1 if -d _dir($self->fltk_dir());
        print "Extracting FLTK...\n";
        require Archive::Extract;
        my $ae = Archive::Extract->new(archive => $archive);
        return 1 if $ae->extract(to => 'src');
        carp 'Error: ', $ae->error;
        return 0;
    }

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

    sub configure {
        my ($self, $build) = @_;
        die 'Failed to find sh; to run "sh ./configure"; bye!'
            if !MBX::Alien::FLTK::Utility::can_run('sh');
        return MBX::Alien::FLTK::Utility::run(qw[sh ./configure]);
    }

    sub build_fltk {
        my ($self, $build) = @_;
        die 'Failed to find sh; to run "make" bye!'
            if !MBX::Alien::FLTK::Utility::can_run('make');
        return MBX::Alien::FLTK::Utility::run(qw[make]);
    }

    # Flags
    sub cflags {
        my ($self, $build) = @_;
        chdir _dir($build->fltk_dir())
            or die q[failed to cd to fltk's directory: ] . $!;
        die 'Failed to find sh; to run "sh ./fltk-config" bye!'
            if !MBX::Alien::FLTK::Utility::can_run('sh');
        my $cflags = qx[sh ./fltk2-config --cflags];
        chomp $cflags;
        return $cflags;
    }

    sub cxxflags {
        my ($self, $build) = @_;
        chdir _dir($build->fltk_dir())
            or die q[failed to cd to fltk's directory: ] . $!;
        die 'Failed to find sh; to run "sh ./fltk-config" bye!'
            if !MBX::Alien::FLTK::Utility::can_run('sh');
        my $cxxflags = qx[sh ./fltk2-config --cxxflags];
        chomp $cxxflags;
        return $cxxflags;
    }

    sub ldflags {
        my ($self, $build) = @_;
        chdir _dir($build->fltk_dir())
            or die q[failed to cd to fltk's directory: ] . $!;
        die 'Failed to find sh; to run "sh ./fltk-config" bye!'
            if !MBX::Alien::FLTK::Utility::can_run('sh');
        my $ldflags = qx[sh ./fltk2-config --ldflags];
        chomp $ldflags;
        return $ldflags;
    }

    # shortcuts
    sub compile {
        my ($self, $args) = @_;
        my $obj
            = $args->{'output'} ? $args->{'output'} : _o($args->{'source'});
        my $command = join ' ', grep defined, $Config{'cc'},    # GCC(.exe)
            '-c',                                               # compile only
            $args->{'source'},                                  # input
            '-o', $obj,                                         # output
            (map { '-I' . qq["$_"] } grep {-d} @{$args->{'include_path'}})
            ,    # include directories
            ($args->{'verbose'} ? '-Wall -W' : ''),    # noise!
            @{$args->{'cxxflags'}};
        print STDERR "$command\n" if $args->{'verbose'};
        return system($command) ? () : $obj;
    }

    sub link_exe {
        my ($self, $args) = @_;
        my $exe
            = $args->{'output'}
            ? $args->{'output'}
            : _exe($args->{'object'}->[0]);
        my $command = join ' ', grep defined,
            $Config{'ld'},           # links with stdc++
            @{$args->{'object'}},    # input
            '-o', $exe,              # output
            (map { '-L' . qq["$_"] } grep {-d} @{$args->{'library_paths'}})
            ,                        # lib directories
            (map { '-l' . $_ } @{$args->{'libs'}}),    # libs
            ($args->{'verbose'} ? '-Wall -W' : ()),    # noise!
            @{$args->{'ldflags'}};
        print STDERR "$command\n" if $args->{'verbose'};
        return () if system($command);
        return wantarray ? ($exe) : $exe;
    }

    sub link_dll {
        my ($self, $args) = @_;
        my $dll
            = $args->{'output'}
            ? $args->{'output'}
            : _dll($args->{'object'}->[0]);
        my $command = join ' ', grep defined, 'g++',    # links with stdc++
            '-shared',               # creates a shared library
            @{$args->{'object'}},    # input
            '-o', $dll,              # output
            (map { '-L' . qq["$_"] } grep {-d} @{$args->{'library_paths'}})
            ,                        # lib directories
            (map { '-l' . $_ } @{$args->{'libs'}}),    # libs
            ($args->{'verbose'} ? '-Wall -W' : ()),    # noise!
            ($args->{'import'}
             ? '-Wl,--out-implib,' . _a($dll)
             : ''
            ),
            @{$args->{'ldflags'}};
        print STDERR "$command\n" if $args->{'verbose'};
        return () if system($command);
        return wantarray ? ($dll, ($args->{'import'} ? _a($dll) : ())) : $dll;

    }

    sub archive {
        my ($self, $args) = @_;
        die if !$args->{'output'};
        my $arch = $args->{'output'};
        my @cmd = (
            qw[ar cr],
            $arch, @{$args->{'objects'}});
        print STDERR "@cmd\n"         if $args->{'verbose'};
        return                        if !MBX::Alien::FLTK::Utility::run(@cmd);
        print STDERR "ranlib $arch\n" if $args->{'verbose'};
        return MBX::Alien::FLTK::Utility::run('ranlib', $arch) ? $arch : ();
    }

    sub test_exe {
        my ($self, $args) = @_;
        my ($exe,  @obj)  = $self->build_exe($args);
        return if !$exe;
        my $return = !system($exe);
        unlink $exe, @obj;
        return $return;
    }

    sub build_exe {
        my ($self, $args) = @_;
        my @obj;
        my $code = 0;
        if (!$args->{'source'}) {
            (my $FH, $args->{'source'})
                = tempfile(undef, SUFFIX => '.cpp', UNLINK => 1);
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
        push @obj,
            $self->compile({source       => $args->{'source'},
                            include_path => $args->{'include_path'},
                            verbose      => $args->{'verbose'},
                            cxxflags     => $args->{'cxxflags'}
                           }
            );
        unlink $args->{'source'} if $code;
        return if !@obj;
        my $exe = $self->link_exe({object        => \@obj,
                                   libs          => $args->{'libs'},
                                   library_paths => $args->{'library_paths'},
                                   verbose       => $args->{'verbose'},
                                   ldflags       => $args->{'ldflags'}
                                  }
        );
        return wantarray ? ($exe, @obj) : $exe;
    }

    sub test_dll {
        my ($self, $args) = @_;
        (my $FH, $args->{'source'})
            = tempfile(undef, SUFFIX => '.cpp', UNLINK => 1);
        syswrite($FH,
                 ($args->{'code'}
                  ? delete $args->{'code'}
                  : 'int main(){return 0;}'
                     )
                     . "\n"
        );
        close $FH;
        my ($dll, @obj) = $self->build_dll($args);
        return if !$dll;
        unlink $dll, @obj;
        return 1;
    }

    sub build_dll {
        my ($self, $args) = @_;
        my @_obj;
        push @_obj,
            $self->compile({source       => $args->{'source'},
                            include_path => $args->{'include_path'},
                            verbose      => $args->{'verbose'},
                            cxxflags     => $args->{'cxxflags'}
                           }
            );
        return 0 if !@_obj;
        my ($dll, @clutter)
            = $self->link_dll({object        => \@_obj,
                               libs          => $args->{'libs'},
                               library_paths => $args->{'library_paths'},
                               verbose       => $args->{'verbose'},
                               import        => $args->{'import'},
                               ldflags       => $args->{'ldflags'},
                              }
            );
        return wantarray ? ($dll, @_obj, @clutter) : $dll;
    }

    sub _archdir {
        my ($self, $p) = @_;
        my ($vol, $dir, $file) = File::Spec->splitpath($p || '');
        File::Spec->catfile($self->install_destination('arch'),
                            qw[Alien FLTK], File::Spec->splitdir($dir),
                            $file);
    }

    sub make_tarball {
        my ($self, $dir, $file, $quiet) = @_;
        $file ||= $dir;
        $self->do_system(
            'tar --mode=0755 -c' . ($quiet ? q[] : 'v') . "f $file.tar $dir");
        $self->do_system("gzip -9 -f -n $file.tar");
        return 1;
    }
    1;
}

__END__

$Id$
