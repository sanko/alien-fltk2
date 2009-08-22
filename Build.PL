use strict;
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

my $class = $is_developer ? 'MBX::Alien::FLTK::Developer' : 'MBX::Alien::FLTK';
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
        'Archive::Extract' => 0,
        base               => 0,
        Carp               => 0,
        Config             => 0,
        Cwd                => 0,
        'File::Basename'   => 0,
        'File::Fetch'      => 0,
        'File::Find'       => 0,
        'File::Path'       => 2.07,
        'File::Spec'       => 0,         # used in A::F proper
        'File::Temp'       => 0,
        'Test::More'       => 0.88,
        'Module::Build'    => 0.3,
        perl               => '5.8.0',
        (  ($^O eq 'VMS') ? ('VMS::DCLsym' => 0)
         : ()
        )
    },
    build_requires => {'Archive::Extract' => 0,
                       base               => 0,
                       Carp               => 0,
                       Config             => 0,
                       Cwd                => 0,
                       'File::Basename'   => 0,
                       'File::Fetch'      => 0,
                       'File::Find'       => 0,
                       'File::Path'       => 2.07,
                       'File::Spec'       => 0,
                       'File::Temp'       => 0,
                       'Test::More'       => 0.88,
                       'Module::Build'    => 0.3,
                       perl               => '5.8.0',
                       (  ($^O eq 'VMS') ? ('VMS::DCLsym' => 0)
                        : ()
                       )
    },
    add_to_cleanup => [qw[Alien-FLTK-* src/*],
                       map {"*$_"} (
                             '.' . $Config{'so'}, $Config{'_o'}, $Config{'_a'}
                       )
    ],
    no_index => {directory => [qw[examples inc]]},
    test_files => \@tests,
    meta_merge => {
        generated_by => 'Conversion, software version 7.0',
        keywords =>
            [qw[Alien FLTK Fast Light Toolkit widget FL GUI UI window 2.0.x]],
        resources => {
            bugtracker => 'http://github.com/sanko/alien-fltk/issues',
            ChangeLog => 'http://github.com/sanko/alien-fltk/commits/master',
            homepage  => 'http://sankorobinson.com/fltk/',
            license => 'http://www.perlfoundation.org/artistic_license_2_0',
            #MailingList => 'TODO',
            repository => 'http://github.com/sanko/alien-fltk/'
        }
    },
    get_options => {'interactive!' => {},
                    'messy!'       => {}
    }
);

#
print sub { my ($x) = @_; chomp $x if !$mb->args('messy'); $x; }
    ->(<<'#END');
 --- --- --- --- --- --- --- --- --- --- --- --- --- --- --- --- --- --- ---
    Buliding FLTK requires a functioning C++ compiler.  Hold on a sec
    while I check some stuff...
#END
if (!$mb->test_exe({verbose => $mb->args('messy')})) {
    print <<'#END'; exit 0; }

    Oops!  I failed to find working compier so I this is where you and I
    part ways.  It's been real.
 --- --- --- --- --- --- --- --- --- --- --- --- --- --- --- --- --- --- ---
#END
printf <<'#END', ($mb->args('messy') ? ' ' x 3 : '');
 %sLooks okay here. Moving on.
 --- --- --- --- --- --- --- --- --- --- --- --- --- --- --- --- --- --- ---
#END

#$mb->notes(use_cairo => 0);           # TODO - MacOS
#$mb->notes(use_x     => 0);           # TODO - find_lib
#$mb->notes(use_glut  => 0);           # TODO
#$mb->notes(use_gl    => 1);
#$mb->notes(use_forms => 0);           # TODO
$mb->notes(fltk_svn => $mb->dist_version =~ m[\.0?(\d+)]);
##################################################################### TODO ###
$mb->notes(automated_testing => $automated_testing       ? 1 : 0);
$mb->notes(release_testing   => $is_developer);
$mb->notes(verbose           => $mb->args('messy')       ? 1 : 0);
$mb->notes(interactive       => $mb->args('interactive') ? 1 : 0);
$mb->notes(test_suite        => \@tests);
$mb->notes(gmtime            => scalar gmtime);
$mb->notes(threads           => $Config{'useithreads'}   ? 1 : 0);
$mb->create_build_script;
##############################################################################
exit 0;

sub find_cb {
    return if -d $_ or -l $_;
    return unless -T $_;
    return unless $_ =~ m[.+\.t$];
    return push @tests, $File::Find::name;
}

BEGIN {    # Tired of getting FAIL-mail from outdated build environments
    if ($] < 5.008008) {    # 5.8.8 is already 3+ years old...
        warn sprintf 'Perl v5.8.8 required--this is only v%vd, stopped', $^V;
        exit 0;
    }
    if ($Module::Build::VERSION < 0.3) {
        warn sprintf
            'Module::Build version 0.3 required--this is only version %s',
            $Module::Build::VERSION;
        exit 0;
    }
}
__END__

$Id$
