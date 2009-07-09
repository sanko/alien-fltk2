#!/usr/bin/perl
use strict;
use warnings;
BEGIN { chdir '../..' if not -d '_build'; }
use Test::More tests => 1;
use Config qw[%Config];
use File::Temp qw[tempfile tempdir];
use File::Spec::Functions qw[rel2abs catfile];
use File::Basename qw[dirname];
use Time::HiRes qw[];
use Module::Build qw[];
use lib qw[blib/lib inc];
use Alien::FLTK;
$|++;
my $test_builder    = Test::More->builder;
my $build           = Module::Build->current;
my $release_testing = $build->config_data('release_testing');
my $verbose         = $build->config_data('verbose');
$SIG{__WARN__} = (
    $verbose
    ? sub {
        diag(sprintf(q[%02.4f], Time::HiRes::time- $^T), q[ ], shift);
        }
    : sub { }
);

#
use lib qw[blib/lib inc];
use_ok('Alien::FLTK');
