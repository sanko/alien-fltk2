package MBX::Alien::FLTK::Utility;
{
    use strict;
    use warnings;
    use Config qw[%Config];
    use File::Spec::Functions qw[splitpath catpath rel2abs];
    use File::Basename qw[];
    use File::Find qw[find];
    use Exporter qw[import];
    our @EXPORT_OK
        = qw[can_run run _o _a _exe _dll find_h _dir _abs _rel _file];

    sub can_run {    # Snagged from IPC::CMD and trimmed for my use
        my ($prog) = @_;

        # a lot of VMS executables have a symbol defined
        # check those first
        if ($^O eq 'VMS') {
            require VMS::DCLsym;
            my $syms = VMS::DCLsym->new;
            return $prog if scalar $syms->getsym(uc $prog);
        }
        require ExtUtils::MM;
        for my $dir ((split /\Q$Config{path_sep}\E/, $ENV{PATH}),
                     File::Spec->curdir)
        {   my $abs = File::Spec->catfile($dir, $prog);
            return $abs if $abs = MM->maybe_command($abs);
        }
    }
    sub run { return !system(join ' ', @_); }

    sub _o {
        my ($vol, $dir, $file) = splitpath(@_);
        $file =~ m[^(.*)(?:\..*)$] or return;
        return catpath($vol, $dir, ($1 ? $1 : $file) . $Config{'_o'});
    }

    sub _a {
        my ($vol, $dir, $file) = splitpath(@_);
        $file =~ m[^(.*)(?:\..*)$];
        return
            catpath($vol,
                    $dir,
                    ($1 && $1 =~ m[^lib] ? '' : 'lib')
                        . ($1 ? $1 : $file)
                        . $Config{'_a'}
            );
    }

    sub _exe {
        my ($vol, $dir, $file) = splitpath(@_);
        $file =~ m[^(.*)(?:\..*)$] or return @_;
        return catpath($vol, $dir, ($1 ? $1 : $file) . $Config{'_exe'});
    }

    sub _dll {
        my ($vol, $dir, $file) = splitpath(@_);
        $file =~ m[^(.*)(?:\..*)$] or return @_;
        return catpath($vol, $dir, ($1 ? $1 : $file) . '.' . $Config{'so'});
    }
    sub _dir  { File::Spec->catdir(@_) }              # XXX - should be locale
    sub _abs  { File::Spec->rel2abs(@_) }
    sub _rel  { File::Spec->abs2rel(@_) }
    sub _file { File::Basename::fileparse(shift); }

    sub find_h {
        my $file = rel2abs(File::Spec->catfile($Config{'incpath'}, shift));
        my $found;
        find(
            sub {    # XXX - Some platforms are touchy about case
                $found = File::Spec->canonpath($File::Find::name)
                    if lc File::Spec->canonpath($File::Find::name) eq
                        lc $file;
            },
            $Config{'incpath'}
        );
        return $found;
    }

    sub find_lib {
        my $file = rel2abs(
                        File::Spec->catfile(
                            $Config{'libpth'}, 'lib' . shift() . $Config{'_a'}
                        )
        );
        die $file;
        my $found = 0;
        find(
            sub {    # XXX - Some platforms are touchy about case
                $found = File::Spec->canonpath($File::Find::name)
                    if lc File::Spec->canonpath($File::Find::name) eq
                        lc $file;
            },
            $Config{'libpth'}
        );
        return $found;
    }
    1;
}
__END__

$Id$