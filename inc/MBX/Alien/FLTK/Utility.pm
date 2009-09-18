package MBX::Alien::FLTK::Utility;
{
    use strict;
    use warnings;
    use Config qw[%Config];
    use File::Spec::Functions qw[splitpath catpath catdir rel2abs canonpath];
    use File::Basename qw[];
    use File::Find qw[find];
    use Exporter qw[import];
    our @EXPORT_OK
        = qw[can_run run _o _a _exe _dll find_h find_lib _dir _abs _rel _file _split];

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
    sub _dir   { File::Spec->catdir(@_) }             # XXX - should be locale
    sub _abs   { File::Spec->rel2abs(@_) }
    sub _rel   { File::Spec->abs2rel(@_) }
    sub _file  { File::Basename::fileparse(shift); }
    sub _split { File::Spec->splitpath(@_) }

    sub _find_lib {
        my ($file, $dir) = @_;

        #$file =~ s[([\+\*\.])][\\$1]g;
        $file = 'lib' . $file . $Config{'_a'};
        $dir = join ' ', ($dir || ''), $Config{'libpth'};
        $dir =~ s|\s+| |g;
        warn $dir;
        for my $test (split m[\s+]m, $dir) {
            warn '    =>' . canonpath($test . '/' . $file) . '<=';
            die 'Worked!' if -e canonpath($dir . '/' . $file);
            return canonpath($test) if -e canonpath($dir . '/' . $file);
        }
        return;
    }

    sub find_lib {
        my ($find, $dir) = @_;
        no warnings 'File::Find';
        $find =~ s[([\+\*\.])][\\$1]g;
        $dir ||= $Config{'libpth'};
        $dir = canonpath($dir);
        my $lib;
        find(
            sub {
                $lib = canonpath(rel2abs($File::Find::dir))
                    if $_ =~ qr[lib$find$Config{'_a'}];
            },
            split ' ',
            $dir
        ) if $dir;
        return $lib;
    }

    sub find_h {
        my ($file, $dir) = @_;
        $dir = join ' ', ($dir || ''), $Config{'incpath'}, $Config{'usrinc'};
        $dir =~ s|\s+| |g;
        for my $test (split m[\s+]m, $dir) {
            return canonpath($test) if -e canonpath($test . '/' . $file);
        }
        return;
    }
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
