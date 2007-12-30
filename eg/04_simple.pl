#!/usr/bin/perl -w
use strict;
use CGI::Auth::Basic;

CGI::Auth::Basic->new(cgi_object => 'AUTOLOAD_CGI', 
                      file       => "./password.txt")->check_user;

print "Content-type: text/html\n\n" . "You can use this program. Now anything that this program does is accessible! :)";


__END__
