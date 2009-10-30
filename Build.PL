use warnings;
use Config qw[%Config];
use File::Find qw[find];
use lib 'inc';
use MBX::Alien::FLTK;
$|++;
my $automated_testing = $ENV{AUTOMATED_TESTING} || $ENV{PERL_MM_USE_DEFAULT};
my $is_developer = ((-d '.git') ? 1 : 0) or ($ENV{RELEASE_TESTING} ? 1 : 0);
my @tests;
find \&find_cb, qw[t/0000_use];
@tests = sort @tests;
my $class
    = $is_developer ? 'MBX::Alien::FLTK::Developer' : 'MBX::Alien::FLTK';

if (!eval "require $class") {
    printf 'Failed to load %s: %s This ain\'t good, so... bye!', $class, $@;
    exit 0;
}
my $mb = $class->new(
    module_name => 'Alien::FLTK',
    license     => 'artistic_2',
    dist_author => 'Sanko Robinson <sanko@cpan.org>',
    dist_abstract =>
        'Installs libraries for the (experimental) 2.0.x branch of the FLTK GUI toolkit',
    requires => {
        'Archive::Extract'   => 0,
        base                 => 0,
        Carp                 => 0,
        Config               => 0,
        Cwd                  => 0,
        'File::Basename'     => 0,
        'File::Fetch'        => 0,
        'File::Find'         => 0,
        'File::Path'         => 2.07,
        'File::Spec'         => 0,          # used in A::F proper
        'File::Temp'         => 0,
        'Test::More'         => 0.88,
        'Module::Build'      => 0.35,
        'ExtUtils::CBuilder' => '0.26_05',
        perl                 => 5.008000,
        (  ($^O eq 'VMS') ? ('VMS::DCLsym' => 0)
         : ()
        )
    },
    build_requires => {'Archive::Extract'   => 0,
                       base                 => 0,
                       Carp                 => 0,
                       Config               => 0,
                       Cwd                  => 0,
                       'File::Basename'     => 0,
                       'File::Fetch'        => 0,
                       'File::Find'         => 0,
                       'File::Path'         => 2.07,
                       'File::Spec'         => 0,
                       'File::Temp'         => 0,
                       'Test::More'         => 0.88,
                       'Module::Build'      => 0.35,
                       'ExtUtils::CBuilder' => '0.26_05',
                       perl                 => 5.008000,
                       (  ($^O eq 'VMS') ? ('VMS::DCLsym' => 0)
                        : ()
                       )
    },
    add_to_cleanup => [qw[Alien-FLTK-* src/*],
                       map {"*$_"} (
                             '.' . $Config{'so'}, $Config{'_o'}, $Config{'_a'}
                       )
    ],
    no_index   => {directory => [qw[t example inc]]},
    test_files => \@tests,
    meta_merge => {
        generated_by => 'Conversion, software version 7.0',
        keywords =>
            [qw[Alien FLTK Fast Light Toolkit widget FL GUI UI window 2.0.x]],
        resources => {
            bugtracker => 'http://github.com/sanko/alien-fltk/issues',
            ChangeLog  => 'http://github.com/sanko/alien-fltk/commits/master',
            homepage   => 'http://sanko.github.com/fltk-perl/',
            license => 'http://www.perlfoundation.org/artistic_license_2_0',

            #MailingList => 'TODO',
            repository => 'http://github.com/sanko/alien-fltk'
        }
    }
);

#
print "Checking for a functioning C++ compiler...\n";
if ($mb->cbuilder->have_cplusplus()) { print "Looks good\n\n" }
else { print "fail\n* No compiler found. Exiting.\n"; exit 0 }

#$mb->notes(use_cairo => 0);           # TODO - MacOS
#$mb->notes(use_x     => 0);           # TODO - find_lib
#$mb->notes(use_glut  => 0);           # TODO
#$mb->notes(use_gl    => 1);
#$mb->notes(use_forms => 0);           # TODO
$mb->notes(fltk_branch => '2.0.x');
$mb->notes(fltk_svn => $mb->dist_version =~ m[\.0?(\d+)]);
##################################################################### TODO ###
$mb->notes(automated_testing => $automated_testing     ? 1 : 0);
$mb->notes(release_testing   => $is_developer);
$mb->notes(test_suite        => \@tests);
$mb->notes(gmtime            => scalar gmtime);
$mb->notes(threads           => $Config{'useithreads'} ? 1 : 0);
############################################################## Get to work ###
for my $action (qw[fetch_fltk extract_fltk configure_fltk write_config_h]) {
    $mb->depends_on($action);
    $mb->dispatch('check_errors');
}
$mb->create_build_script;
##############################################################################
exit 0;

sub find_cb {
    return if -d $_ or -l $_;
    return unless -T $_;
    return unless $_ =~ m[.+\.t$];
    return push @tests, $File::Find::name;
}

=pod

=head1 NAME

Build.PL - Module::Build based install

=head1 Description

C<Build.PL> creates the 'Build' script which... meh, you know what C<Build.PL>
is for.

Anyway, when this one decides that it is being run by an L<Alien::FLTK>
Developer (or just some random person who checked out the source from git) it
loads a "special" L<Module::Build|Module::Build> subclass filled with useless
things I've wasted my time pasting together. Otherwise, it loads a rather tame
subclass which works well enough for most end users.

=head1 Requirements

=over

=item L<Alien::FLTK|Alien::FLTK> is licensed under the Artistic License 2.0
(see the L<License and Legal|/"License and Legal"> section) so this
C<Build.PL> requires at least L<Module::Build|Module::Build> C<0.3>.

=item I've set an arbitrary minimum perl version at 5.8.8 not because I've
tested L<Alien::FLTK|Alien::FLTK> with anything lower than that and failed,
but because I really don't care for test reports from ancient builds.

=back

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
