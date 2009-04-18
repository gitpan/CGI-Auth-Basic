#!/usr/bin/perl
use ExtUtils::MakeMaker;

WriteMakefile(
    'NAME'         => 'CGI::Auth::Basic',
    'VERSION_FROM' => 'lib/CGI/Auth/Basic.pm',
    'PREREQ_PM'    => {
        'Test::More' => '0.40',
    },
    ($] >= 5.005 ? (
    'AUTHOR'       => 'Burak Gursoy <burak@cpan.org>',
    'ABSTRACT'     => 'Basic CGI authentication interface',
    ) : ()),
    PL_FILES       => {},
);
