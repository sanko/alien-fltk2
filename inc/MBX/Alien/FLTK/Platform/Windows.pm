package MBX::Alien::FLTK::Platform::Windows;
{
    use strict;
    use warnings;
    use Carp qw[];
    use Config qw[%Config];
    use lib qw[.. ../../../.. inc];
    use MBX::Alien::FLTK::Utility
        qw[_o _a _dir _rel _abs find_h find_lib can_run];
    use MBX::Alien::FLTK;
    use base 'MBX::Alien::FLTK::Base';
    $|++;

    sub configure {
        my ($self) = @_;
        $self->SUPER::configure();    # Get basic config data
        print "Gathering Windows specific configuration data...\n";
        $self->notes(ldflags => $self->notes('ldflags')
                 . ' -mwindows -lmsimg32 -lole32 -luuid -lcomctl32 -lwsock32 '
        );
        $self->notes(
              'cxxflags' => ' -mwindows -DWIN32 ' . $self->notes('cxxflags'));
        $self->notes('config')->{'HAVE_STRCASECMP'}    = undef;
        $self->notes('config')->{'HAVE_STRNCASECMP'}   = undef;
        $self->notes('config')->{'HAVE_STRNCASECMP'}   = undef;
        $self->notes('config')->{'HAVE_DIRENT_H'}      = undef;
        $self->notes('config')->{'HAVE_SYS_NDIR_H'}    = undef;
        $self->notes('config')->{'HAVE_SYS_DIR_H'}     = undef;
        $self->notes('config')->{'HAVE_NDIR_H'}        = undef;
        $self->notes('config')->{'HAVE_SCANDIR'}       = undef;
        $self->notes('config')->{'HAVE_SCANDIR_POSIX'} = undef;
        {
            print 'Checking for OpenGL... ';
            my $GL_LIB = '';
            $self->notes('config')->{'HAVE_GL'} = 0;
            if (!$self->assert_lib(lib => 'opengl32', header => 'GL/gl.h')) {
                print "no\n";
                push @{$self->notes('errors')},
                    {stage   => 'configure',
                     fatal   => 0,
                     message => 'OpenGL libs were not found'
                    };
            }
            else {
                $self->notes('config')->{'HAVE_GL'} = 1;
                print "okay\n";
                $GL_LIB = '-lopengl32';

                #
                print 'Checking for GL/glu.h... ';
                $self->notes('config')->{'HAVE_GL_GLU_H'} = 0;
                if (!$self->assert_lib(lib => 'glu32', header => 'GL/glu.h'))
                {   print "no\n";
                }
                else {
                    $self->notes('config')->{'HAVE_GL_GLU_H'} = 1;
                    print "okay\n";
                    $GL_LIB = " -lglu32 $GL_LIB ";
                }
            }
            $self->notes(GL => $GL_LIB);
        }
        return 1;
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
