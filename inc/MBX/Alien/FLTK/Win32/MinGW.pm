package MBX::Alien::FLTK::Win32::MinGW;
{
    use strict;
    use warnings;
    use lib '../../..';
    use base 'MBX::Alien::FLTK::Win32';

    #
    sub version { return qx[gcc -dumpversion]; }
}
1;
__END__

$Id$
