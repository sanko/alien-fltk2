#!/usr/bin/perl
use strict;
use warnings;
use Test::More tests => 1;
use Config qw[%Config];
use File::Temp qw[tempfile];
use Time::HiRes qw[];
use Module::Build;
$|++;
my $test_builder = Test::More->builder;
chdir '../..' if not -d '_build';
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
