#!/usr/bin/env perl -w
# Simple test. Just try to use the module.
use strict;
use Test::More;
BEGIN { plan tests => 1 }

use CGI::Auth::Basic; 
ok(1);

exit;

__END__
