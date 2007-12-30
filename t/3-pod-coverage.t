#!/usr/bin/env perl -w
use strict;
use Test::More;

eval "use Test::Pod::Coverage;1";
plan skip_all => "Test::Pod::Coverage required for testing pod coverage" if $@;
plan tests => 1;
unless($@) {
   pod_coverage_ok('CGI::Auth::Basic');
}
