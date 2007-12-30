use strict;
use Module::Build;
Module::Build->new(
    module_name => 'CGI::Auth::Basic',
    license     => 'perl',
    requires    => {
       'Test::More' => 0,
    },
    dist_author => 'Burak Gursoy <burak@cpan.org>',
)->create_build_script;
