use ExtUtils::MakeMaker;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
WriteMakefile(
    'NAME'         => 'CGI::Auth::Basic',
    'VERSION_FROM' => 'lib/CGI/Auth/Basic.pm',
    'PREREQ_PM'    => { 'CGI' => 0, 'Fcntl' => 0 },
    ($] >= 5.005 ? (
    'AUTHOR'       => 'Burak Gursoy <burak@cpan.org>',
    'ABSTRACT'     => 'Basic CGI authentication interface',
     ) : ()),
);
