package MBX::Alien::FLTK;
{
    use strict;
    use warnings;
    use Config qw[%Config];
    use Module::Build;
    use lib '../..';
    use base 'MBX::Alien::FLTK::Base';
    use vars qw[@ISA];

    sub new {
        my ($class, %args) = @_;
        shift;
        my $self     = $class->SUPER::new(@_);
        my $OS       = $args{'osname'} || $Config{'osname'} || $^O;
        my $CC       = $args{'cc'} || $Config{'ccname'} || $Config{'cc'};
        my @platform = grep defined, $OS =~ m[Win32]
            ? (
            'Windows',
            ($CC =~ m[gcc]i
             ? 'MinGW'
             : $CC =~ m[cl]i    ? 'MSVC'       # TODO - use .proj
             : $CC =~ m[bcc32]i ? 'Borland'    # TODO
             : $CC =~ m[icl]i   ? 'Intel'      # TODO
             : ()                              # Hope for the best
            )
            )
            : $OS =~ m[CygWin]i ? ('Windows', 'CygWin')    # ...baka
            : $OS =~ m[Darwin]i  ? 'Darwin'     # Mac OSX
            : $OS =~ m[BSD$]i    ? 'BSD'        # requires GNUmake (gmake)
            : $OS =~ m[Solaris]i ? 'Solaris'    # requires GNUmake (gmake)
            : $OS =~ m[IRIX]i    ? 'IRIX'       # requires GNUmake (gmake)
            :                      'Unix';
        my $platform = 'MBX::Alien::FLTK::Platform';
        for my $qual (@platform) {
            $platform .= '::' . $qual;
            eval "use $platform";
            next if $@;
            unshift @ISA, $platform;
        }
        $self->notes(platform => \@platform);
        $self->notes(os       => $OS);
        $self->notes(cc       => $CC);
        $self->notes(errors   => []);
        return $self;
    }

    sub resume {
        my $self      = shift->SUPER::resume(@_);
        my $platform  = $self->notes('platform');
        my $_platform = 'MBX::Alien::FLTK::Platform';
        for my $qual (@$platform) {
            $_platform .= '::' . $qual;
            eval "use $_platform";
            next if $@;
            unshift @ISA, $_platform;
        }
        return $self;
    }
    sub VERBOSE { !shift->quiet() }
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
