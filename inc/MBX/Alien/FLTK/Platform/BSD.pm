package MBX::Alien::FLTK::Platform::BSD;
{
    use strict;
    use warnings;
    use Carp qw[];
    use Config qw[%Config];
    use lib qw[.. ../../../..];
    use MBX::Alien::FLTK::Utility qw[_o _a _dir _rel _abs];
    use base 'MBX::Alien::FLTK';
    sub new { bless \$0, shift }

    sub build_fltk {    # TODO: Try $Config{'make'} second
        my ($self, $build) = @_;
        return MBX::Alien::FLTK::Utility::run(qw[gmake])
            if MBX::Alien::FLTK::Utility::can_run('gmake');
        print 'Failed to find GNUmake which is required for *BSD';
        exit 0;
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
