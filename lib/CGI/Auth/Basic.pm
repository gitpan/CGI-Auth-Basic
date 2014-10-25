package CGI::Auth::Basic;
use strict;
use vars qw[$VERSION $AUTOLOAD $RE %ERROR $FATAL_HEADER $CAN_CRYPT];

$VERSION = '1.11';

CHECK_CRYPT: {
   eval "crypt('aa','aa')"; # The crypt() function is unimplemented due to excessive paranoia
   $CAN_CRYPT = $@ ? 0 : 1;
   if ( ! $CAN_CRYPT ) {
      eval {require Crypt::UnixCrypt};
      die "Your perl version does not implement crypt(). Upgrade perl or Install Crypt::UnixCrypt" if $@;
   }
}

$RE = qr[^\w\./]; # regex for passwords

# Fatal and other error messages
%ERROR = (
   INVALID_OPTION    => "Options must be in 'param => value' format!",
   CGI_OBJECT        => "I need a CGI object to run!!!",
   FILE_READ         => "Error opening pasword file: ",
   NO_PASSWORD       => "No password specified (or password file can not be found)!",
   UPDATE_PFILE      => "Your password file is empty and your current setting does not allow this code to update the file! Please update your password file.",
   ILLEGAL_PASSWORD  => "Illegal password! Not accepted. Go back and enter a new one",
   FILE_WRITE        => "Error opening password file for update: $!",
   UNKNOWN_METHOD    => "There is no method called '<b>%s</b>'. Check your coding.",
   EMPTY_FORM_PFIELD => "You didn't set any password (password file is empty)!",
   WRONG_PASSWORD    => "<p>Wrong password!</p>",
   INVALID_COOKIE    => "Your cookie info includes invalid data and it has been deleted by the program.",
);

sub new {
   my $class = shift;
   my $self  = {};
   bless $self, $class;
   $self->_fatal($ERROR{INVALID_OPTION}) if scalar(@_) % 2;
   my %o = @_;

   if ($o{cgi_object} eq 'AUTOLOAD_CGI') {
      require CGI;
      $o{cgi_object} = CGI->new;
   } else {
      # long: i_have_another_cgi_like_object_and_i_want_to_use_it
      # don't know if such a module exists :p
      unless ($o{ihacloaiwtui}) {
         ref $o{cgi_object} eq 'CGI' or $self->_fatal($ERROR{CGI_OBJECT});
      }
   }

   my $password;
   if ($o{file} and -e $o{file} and not -d $o{file}) {
      $self->{password_file_path} = $o{file};
      # Don't execute until check_user() called.
      $password = sub {$self->_pfile_content};
   } else {
      $password = $o{password};
   }

   $self->_fatal($ERROR{NO_PASSWORD}) unless $password;

   $self->{password}       = $password;
   $self->{cgi}            = $o{cgi_object};
   $self->{program}        = $self->{cgi}->url  || '';

   # object tables           user specified         default
   $self->{cookie_id}      = $o{cookie_id}      || 'authpass';
   $self->{http_charset}   = $o{http_charset}   || 'ISO-8859-1';
   $self->{logoff_param}   = $o{logoff_param}   || 'logoff';
   $self->{changep_param}  = $o{changep_param}  || 'changepass';
   $self->{cookie_timeout} = $o{cookie_timeout} || '';
   $self->{setup_pfile}    = $o{setup_pfile}    || 0;
   $self->{chmod_value}    = $o{chmod_value}    || 0777;
   $self->{use_flock}      = $o{use_flock}      || 1;
   $self->{hidden}         = $o{hidden}         || [];
   unless(ref($self->{hidden}) and ref($self->{hidden}) eq 'ARRAY') {
      $self->_fatal("hidden parameter must be an arrayref!")
   }
   my $hidden;
   my @hidden_q;
   foreach (@{ $self->{hidden} }) {
      next if $_->[0] eq $self->{cookie_id}; # password!
      next if $_->[0] eq $self->{cookie_id} . '_new'; # password!
      $hidden .= qq~<input type="hidden" name="$_->[0]" value="$_->[1]">\n~;
      push @hidden_q,  $_->[0]."=".$_->[1];
   }
   $self->{hidden_q} = @hidden_q ? join("&",@hidden_q) : "";
   $self->{hidden} = $hidden || "";

   $self->{logged_in}      = 0;
   # Temporary template variables (but some are not temporary :))
   $self->{$_} = '' foreach qw[
                                page_form_error 
                                page_logoff_link 
                                page_content 
                                page_title
                                _TEMPLATE_TITLE
                                _TEMPLATE_TITLE_USER
                                _TEMPLATE_NAMES
                               ];
   $self->{EXIT_PROGRAM} = sub {CORE::exit()};
   $self->_init;
   return $self;
}

sub _crypt {
   my $plain = shift;
   my $salt  = shift;
   return $CAN_CRYPT ? crypt($plain, $salt)
                     : Crypt::UnixCrypt::crypt($plain, $salt);
}

sub exit_code {
   my $self = shift;
   my $code = shift || return;
   if (ref $code and ref $code eq 'CODE') {
      $self->{EXIT_PROGRAM} = $code;
   }
}

sub _init {
   my $self = shift;
   # Set default titles
   $self->{_TEMPLATE_TITLE} = {
   title_login_form       => 'Login',
   title_cookie_error     => 'Your invalid cookie has been deleted by the program',
   title_login_success    => 'You are now logged-in',
   title_logged_off       => 'You are now logged-off',
   title_change_pass_form => 'Change password',
   title_password_created => 'Password created',
   title_password_changed => "Password changed successfully",
   title_error            => 'Error',
   };
   $self->{_TEMPLATE_TITLE_USER} = {};
   $self->{_TEMPLATE_NAMES}      = [ qw( login_form screen logoff_link change_pass_form ) ];
}

sub _setup_password {
   my $self = shift;
      $self->_fatal($ERROR{UPDATE_PFILE}) unless $self->{setup_pfile};
   unless ($self->{cgi}->param('change_password')) {
      $self->_screen(content => $self->_change_pass_form($ERROR{EMPTY_FORM_PFIELD}),
                    title   => $self->_get_title('change_pass_form'));
   }
   my $password = $self->{cgi}->param($self->{cookie_id}.'_new');
   $self->_check_password($password);
   $self->_update_pfile($password);
   $self->_screen(content => $self->_get_title('password_created'),
                 title   => $self->_get_title('password_created'),
                 cookie  => $self->_empty_cookie,
                 forward => 1);
}

sub _check_password {
   my $self     = shift;
   my $password = shift;
   $self->_error($ERROR{ILLEGAL_PASSWORD}) 
    if not $password or
           $password =~ /\s/  or 
       length($password) < 3  or 
       length($password) > 32 or
       $password =~ /$RE/;
}

sub _update_pfile {
   my $self     = shift;
   my $password = shift;
   open  PASSWORD, '>'.$self->{password_file_path} or $self->_fatal($ERROR{FILE_WRITE}." $!");
   flock PASSWORD,Fcntl::LOCK_EX() if $self->{use_flock};
   print PASSWORD $self->_encode($password);
   flock PASSWORD,Fcntl::LOCK_UN() if $self->{use_flock};
   close PASSWORD;
   chmod $self->{chmod_value}, $self->{password_file_path};
}

sub _pfile_content {
   my $self = shift;
   local $/;
   open PASSWORD, $self->{password_file_path} or $self->_fatal($ERROR{FILE_READ}." $!");
   chomp(my $flat = <PASSWORD>);
   close PASSWORD;
   $flat =~ s,\s,,gs;
   return $flat;
}

sub check_user {
   my $self = shift;
   $self->_check_user_real;

   # We have a valid user. Below are accessible as user functions
   if ($self->{cgi}->param($self->{changep_param})) {
      unless ($self->{cgi}->param('change_password')) {
         $self->_screen(content => $self->_change_pass_form,
                       title   => $self->_get_title('change_pass_form'));
      }
      my $password = $self->{cgi}->param($self->{cookie_id}.'_new');
      $self->_check_password($password);
      $self->_update_pfile($password);
      $self->_screen(content => $self->_get_title('password_changed'),
                    title   => $self->_get_title('password_changed'),
                    cookie  => $self->_empty_cookie,
                    forward => 1);
   }
}

# Main method to validate a user
sub _check_user_real {
   my $self = shift;
   my $pass_param;

   if(ref($self->{password}) eq 'CODE') {
      require Fcntl; # we need flock constants
      $self->{password} = $self->{password}->() || $self->_setup_password;
   }

   if ($self->{cgi}->param($self->{logoff_param})) {
      $self->_screen(content => $self->_get_title('logged_off'),
                    title   => $self->_get_title('logged_off'),
                    cookie  => $self->_empty_cookie,
                    forward => 1);
   }

   # Attemp to login via form
   if ($pass_param = $self->{cgi}->param($self->{cookie_id})){
      if ($pass_param !~ m/$RE/ and $self->_match_pass($pass_param)) {
         $self->{logged_in} = 1;
         $self->_screen(content => $self->_get_title('login_success'),
                       title   => $self->_get_title('login_success'),
                       forward => 1,
                       cookie  => $self->{cgi}->cookie(-name    => $self->{cookie_id},
                                                       -value   => $self->{password}),
                                                       -expires => $self->{cookie_timeout});
      } else {
         $self->_screen(content => $self->_login_form($ERROR{WRONG_PASSWORD}), 
                       title   => $self->_get_title('login_form'));
      }
   # Attemp to login via cookie
   } elsif ($pass_param = $self->{cgi}->cookie($self->{cookie_id})) {
      if($pass_param !~ m,$RE, and $pass_param eq $self->{password}) {
         $self->{logged_in} = 1;
         return 1;
      } else {
         $self->_screen(content => $ERROR{INVALID_COOKIE},
                       title   => $self->_get_title('cookie_error'),
                       cookie  => $self->_empty_cookie,
                       forward => 1);
      }
   } else {
      $self->_screen(content => $self->_login_form,
                    title   => $self->_get_title('login_form'));
   }
}

# Private method. Used internally to compile templates
sub _compile_template {
   my $self = shift;
   my $key  = shift;
   my $code = $self->{'template_'.$key};
   return unless $code;
   my $param;
      $code =~ s[<\?(?:\s+|)(\w+)(?:\s+|)\?>]
                [
                   $param = lc $1; 
                   if ($param !~ m,\W,s and exists $self->{$param}) {
                      $self->{$param};
                   }
                ]segox;
   return $code;
}

sub _get_title {
   my $self  = shift;
   my $key   = shift or return;
   return $self->{_TEMPLATE_TITLE_USER}{'title_'.$key} || $self->{_TEMPLATE_TITLE}{'title_'.$key};
}

sub set_template {
   my $self = shift;
   $self->_fatal($ERROR{INVALID_OPTION}) if scalar(@_) % 2;
   my %o = @_;
   if ($o{delete_all}) {
      foreach my $key (keys %{$self}) {
         delete $self->{$key} if $key =~ /^template_/;
      }
      $self->{_TEMPLATE_TITLE_USER} = {};
   } else {
      foreach my $key (@{ $self->{_TEMPLATE_NAMES} }) {
         $self->{'template_'.$key} = $o{$key} if exists $o{$key};
      }
   }
   return 1;
}

sub set_title {
   my $self = shift;
   $self->_fatal($ERROR{INVALID_OPTION}) if scalar(@_) % 2;
   my %o = @_;
   foreach (keys %o) {
      $self->{_TEMPLATE_TITLE_USER}{'title_'.$_} = $o{$_} if $self->{_TEMPLATE_TITLE}{'title_'.$_};
   }
}

sub _login_form {
   my $self = shift;
      $self->{page_form_error} = shift if $_[0];
   my $code = $self->_compile_template('login_form')
              ||
              qq~
<span class="error">$self->{page_form_error}</span>
<form action="$self->{program}" method="post">

<table border="0" cellpadding="0" cellspacing="0">
 <tr><td class="darktable">
  <table border="0" cellpadding="4" cellspacing="1">
 <tr>
   <td class="titletable" colspan="3">You need to login to use this function</td>
 </tr>
 <tr>
  <td class="lighttable">Enter <i>the</i> password to run this program:</td>
  <td class="lighttable"><input type="password" name="$self->{cookie_id}"></td>
  <td class="lighttable" align="right">
  <input type="submit" name="submit" value="Login">
  $self->{hidden}
  </td>
 </tr>
</table>
</td> </tr>
</table>
</form>
   ~;
   return $code;
}

sub _change_pass_form {
   my $self = shift;
      $self->{page_form_error} = shift if $_[0];
   my $code = $self->_compile_template('change_pass_form')
              ||
              qq~
<span class="error">$self->{page_form_error}</span>
<form action="$self->{program}" method="post">

<table border="0" cellpadding="0" cellspacing="0">
 <tr><td class="darktable">
  <table border="0" cellpadding="4" cellspacing="1">
 <tr>
   <td class="titletable" colspan="3">
   Enter a password between 3 and 32 characters and no spaces allowed!</td>
 </tr>
 <tr>
  <td class="lighttable">Enter your new password:</td>
  <td class="lighttable"><input type="password" name="$self->{cookie_id}_new"></td>
  <td class="lighttable" align="right">
  <input type="submit" name="submit" value="Change Password">
  <input type="hidden" name="change_password" value="ok"></td>
  <input type="hidden" name="$self->{changep_param}" value="1"></td>
  $self->{hidden}
 </tr>
</table>
</td> </tr>
</table>
</form>~;
}

sub logoff_link {
   my $self = shift;
   my $query = $self->{hidden_q} ? "&".$self->{hidden_q} : "";
   return $self->_compile_template('logoff_link')
           ||
          qq~<span class="small">[<a href="$self->{program}?$self->{logoff_param}=1$query">Log-off</a> - <a href="$self->{program}?$self->{changep_param}=1$query">Change password</a>]</span> ~ if $self->{logged_in};
   return '';
}

# For form errors
sub _error { 
   my $self  = shift;
   my $error = shift;
   $self->_screen(content => qq~<span class="error">$error</span>~, title => $self->_get_title('error'));
}

sub _screen {
   my $self   = shift;
   my %p      = scalar(@_) % 2 ? () : @_;
   my @cookie = $p{cookie} ? (-cookie => $p{cookie}) : (); 

   my $refresh_url;
   if ( $self->{hidden_q} ) {
      $refresh_url = "$self->{program}?$self->{hidden_q}";
   } else {
      my @qs;
      foreach my $p ( $self->{cgi}->param ) {
         next if $p eq $self->{logoff_param};
         next if $p eq $self->{changep_param};
         next if $p eq $self->{cookie_id};
         next if $p eq $self->{cookie_id} . '_new';
         push @qs, $p . '=' . $self->{cgi}->param( $p );
      }
      my $url = $self->{program};
      if ( @qs ) {
         $url =~ s{\?}{}xmsg;
         $url .= '?' . join('&', @qs);
      }
      $refresh_url = $url;
   }

   # Set template vars
   $self->{page_logoff_link}    = $self->logoff_link;
   $self->{page_content}        = $p{content};
   $self->{page_title}          = $p{title};
   $self->{page_refresh}        = $p{forward} ? qq~<meta http-equiv="refresh" content="0; url=$refresh_url">~ : '';
   $self->{page_inline_refresh} = $p{forward} ? qq~<a href="$refresh_url">&#187;</a>~ : '';
   my $out = $self->_compile_template('screen')
              ||
             qq~<html>
   <head>
    $self->{page_refresh}
    <title>$self->{page_title}</title>
    <style>
      body       {font-family: Verdana, sans; font-size: 10pt}
      td         {font-family: Verdana, sans; font-size: 10pt}
     .darktable  { background: black;   }
     .lighttable { background: white;   }
     .titletable { background: #dedede; }
     .error      { color = red; font-weight: bold}
     .small      { font-size: 8pt}
    </style>
   </head>
   <body>
      $self->{'page_logoff_link'}
      $self->{'page_content'}
      $self->{'page_inline_refresh'}
   </body>
   </html>~;
   print $self->{cgi}->header(-charset => $self->{http_charset},@cookie).$out;
   $self->_exit_program;
}

sub fatal_header {
   my $self = shift;
   if (@_) {
      $FATAL_HEADER = shift;
   } else {
      return $FATAL_HEADER || qq~Content-Type: text/html; charset=ISO-8859-1\n\n~;
   }
}

# Trap deadly errors
sub _fatal {
   my $self      = shift;
   my $error     = shift || '';
   my @rep       = caller 0;
   my @caller    = caller 1;
      $rep[1]    =~ s,.*[\\/],,;
      $caller[1] =~ s,.*[\\/],,;
   my $class     = ref $self;
   my $fatal     = $self->fatal_header;
      $fatal    .= qq~<html>
      <head>
       <title>Flawless Victory</title>
       <style>
        body  {font-family: Verdana, sans; font-size: 11pt}
       .error { color : red }
       .finfo { color : gray}
       </style>
      </head>
      <body>
      <h1>$class $VERSION - Fatal Error</h1>
      <span class="error">$error</span> 
      <br>
      <br>
      <span class="finfo">Program terminated at <b>$caller[1]</b>
      (package <b>$caller[0]</b>) line <b>$caller[2]</b>.
      <br>
      Error occurred in <b>$rep[0]</b> line <b>$rep[2]</b>.
      </span>
      </body>
      </html>~;
   print $fatal;
   $self->_exit_program;
}

sub _match_pass  {
   my $self = shift;
   my $form = shift;
   return _crypt($form, substr($self->{password},0,2)) eq $self->{password};
}

sub _encode   {
   my $self  = shift;
   my $plain = shift;
   return _crypt($plain, join('',('.','/',0..9,'A'..'Z','a'..'z')[rand 64,rand 64]));
}

sub _empty_cookie {
   my $self = shift;
   return $self->{cgi}->cookie(-name    => $self->{cookie_id},
                               -value   => '', 
                               -expires => '-10y')
}

sub _exit_program {
   my $exit = shift->{EXIT_PROGRAM};
   $exit ? $exit->() : exit;
}

sub AUTOLOAD {
   my $self = shift;
   my $name = $AUTOLOAD;
      $name =~ s,.*:,,;
      $self->_fatal(sprintf $ERROR{UNKNOWN_METHOD}, $name);
}

sub DESTROY {}

1;

__END__

=head1 NAME

CGI::Auth::Basic - Basic CGI authentication interface.

=head1 SYNOPSIS

   use CGI::Auth::Basic;

   $auth = CGI::Auth::Basic->new(cgi_object => $cgi, 
                                 password   => 'J2dmER4GGQfzA');

   $auth = CGI::Auth::Basic->new(cgi_object => $cgi, 
                                 file       => "path/to/password/file.txt");

   $auth = CGI::Auth::Basic->new(cgi_object     => 'AUTOLOAD_CGI',
                                 password       => 'J2dmER4GGQfzA', 
                                 cookie_id      => 'passcookie',
                                 cookie_timeout => '1h',
                                 http_charset   => 'ISO-8859-9',
                                 logoff_param   => 'logout');

   if ($someone_wants_to_enter_my_secret_area) {
      $auth->check_user;
   }

or you can just say:

   CGI::Auth::Basic->new(cgi_object=>CGI->new,file=>"./pass.txt")->check_user;

   # J2dmER4GGQfzA == blah

=head1 DESCRIPTION

This module adds a simple (may be a little complex if you use all
features) user validation system on top of your program. If you have 
a basic utility that needs a password protection or some unfinished 
admin section and you don't want to waste your time with writing 
hundreds of lines of code to protect this area; this module can be useful.

Module's interface is really simple and you can only have a password area;
no username, no other profile areas. This is not a member system afterall 
(or we can say that; this is a basic, single member system -- or call
it a quick hack that does its job). Not designed for larger applications.

=head2 Public Methods

=head3 new

Parameters

=over 4

=item cgi_object

The module needs a C<CGI> object to work. It is used for:

=over 8

=item *

Fetching parameters resulted from a C<POST> or C<GET> request 
(eg: for login and logoff respectively).

=item *

Implementing/fetching/deleting password cookies.

=item *

Getting the name and url of your program.

=item *

Printing HTTP Headers for the module' s GUI.

=back

If you don't use/need a C<CGI> object in your program, set the
parameter to C<AUTOLOAD_CGI>:

   $obj = CGI::Auth::Basic->new(cgi_object => 'AUTOLOAD_CGI' ...)

Then, C<CGI::Auth::Basic> will load the CGI module itself and create 
a C<CGI> object, which you can not access (however, you can access 
with the related object table -- but this'll be weird. Create a C<CGI>
object yourself, if you need one and pass it to the module).

If you don't want to use the C<CGI> class, then you have to 
give the module a similar object which has these methods: 
C<param>, C<cookie>, C<header> and C<url>. They have to work as 
the same as C<CGI> object's methods. If this object does not
match this requirement, your program may die or does not function
properly. Also pass C<ihacloaiwtui> parameter with a true value 
to C<new()>:

   $obj = CGI::Auth::Basic->new(cgi_object   => $my_other_object,
                                ihacloaiwtui => 1, ... )

This string is the short form of
C<i_have_another_cgi_like_object_and_i_want_to_use_it>. 
Yes, this parameter' s name is I<weird> (and silly), but I 
couldn't find a better one.

=item ihacloaiwtui

See C<cgi_object>.

=item password

You need a password to validate the user. If you set this parameter,
it'll be used as the encoded password string. Note that; it B<MUST>
be a crypt()ed string. You must encode it with Perl's C<crypt()> 
function. You can not login with a plain password string.

=item file

If you can't provide a password to the module, set this parameter's 
value to a valid file path. It'll be your password file and will be 
updated (change your password) if necessary. The module will use 
this file to store/fetch password string. If the file does not exist, 
the module will exit with an error. If the file is empty and you set
the C<setup_pfile> parameter to a true value, you'll be prompted to 
enter a password for the first time.

You can not use C<password> and C<file> parameters together. You must 
select one of them to use.

Note that: you must protect your password file(s). Put it above your
web root if you can. Also, giving it a I<.cgi> extension can be 
helpful; if a web server tries to execute it, you'll get a 500 ISE,
not the source (you can get the source however; it depends on your
server software, OS and configuration). You can also put it in
a hard-to-guess named directory. But don't put it in your program 
directory.

Also note that: these are I<just> suggestions and there is no 
guarantee that any of this will work for you. Just test and see
the results.

=item setup_pfile

If your "I<password file>" is empty and you set this parameter to a 
true value, then the module will ask you to enter a password for the
first time and will update the password file. Note that: someone 
that runs the program will set the default value. Also, if you 
forgot your password, set this parameter. You can replace your password 
file with an empty file and run the program to set the password. You 
can turn off this option after the password is set.

=item cookie_id

The name of the cookie and the name of the password area name 
in the login form. Default value is I<password>.

=item http_charset

If you are using custom templates and changed the interface language,
set this to a correct value. Defaut is C<ISO-8859-1> (english).

=item logoff_param

Default value is C<logoff>. If the user is logged-in, you can show him/her
a logoff link (see L<logoff_link|/logoff_link> method). With the default value, 
You'll get this link:

   <your_program>?logoff=1

If you set it to C<logout>, you'll get:

   <your_program>?logout=1

Just a cosmetic option, but good for translation.

=item cookie_timeout

When the user sends the correct password via the login form, the 
module will send a password cookie to the user. Set this parameter 
if you want to alter the module's setting. Default is an empty string
(means; cookie is a session cookie, it'll be deleted as soon as the user 
closes all browser windows)

=item changep_param

Form area name for password change. Same as C<logoff_param>. Cosmetic
option.

=item chmod_value

Password file's chmod value. Default value is C<0777>. Change this value 
if you get file open/write errors or want to use different level of 
permission. Takes octal numbers like C<0777>.

=item use_flock

Default value is C<1> and C<flock()> will be used on filehandles. You can 
set this to zero to turn off flock for platforms that does not implement 
flock (like Win9x).

=item hidden

If the area you want to protect is accessible with some parameters, 
use this option to set the hidden form areas. Passed as an array of 
array, AoA:

   hidden => [
               [action => 'private'],
               [do     => 'this'],
   ],

They'll also be used in the refresh pages and links as a query string.

=back

=head3 check_user

The main method. Just call it anywhere in your code. You do 
not have to pass any parameters. It'll check if the user knows 
the password, and until the user enters the real password, he/she 
will see the login screen and can not run any code below. For example
you can password-protect an admin section like this.

=head3 set_template

Change the module GUI. Create custom templates. Available templates:
C<login_form>, C<change_pass_form>, C<screen>, C<logoff_link>.

   $auth->set_template(login_form => qq~ ... ~, ...);

If you want to load the default templates on some part of
the program, pass C<delete_all> parameter with a true value:

   $auth->set_template(delete_all => 1);

This can be good for debugging and note that this will delete
anything you've set before.

For examples, see the test directory in the distribution.

=head3 set_title

Create your custom page titles. You can need this if you 
want to translate the interface. Available templates:
C<login_form>, C<cookie_error>, C<login_success>, C<logged_off>, 
C<change_pass_form>, C<password_created>, C<password_changed>, 
C<error>.

   $auth->set_title(error => "An error occurred", ...)

If you want to load the default titles on some part of
the program, pass C<delete_all> parameter with a true value 
to L<set_template|/set_template>:

   $auth->set_template(delete_all => 1);

For examples, see the test directory in the distribution.

In the templates, you can only use some pre-defined variables
(some are accesible only in one template). These variables are
enclosed by C<E<lt>?> and C<?E<gt>> (eg: C<E<lt>?>PROGRAMC<?E<gt>>).
The variable's name is case-insensitive (you can write:  
C<E<lt>?>ProGrAmC<?E<gt>>). Because this module does not use/subclass 
any Template module; you can not use any template loops or such things 
that most of the template modules' offer. 

=head3 logoff_link

Returns the code that includes logoff and change password links if the 
user is logged-in, returns an empty string otherwise.

=head3 exit_code

Sets the exit code. By default, CORE::exit() will be called. But you can 
change this behaviour by using this method. Accepts a subref:

   $auth->exit_code(sub { Apache->exit });

You can also do some clean up before exiting:

   $auth->exit_code(sub {
      untie %session;
      $dbh->disconnect;
      exit;
   });

=head2 Class Methods

=head3 fatal_header

Sets the HTTP Header for C<fatal()>. Example:

   CGI::Auth::Basic->fatal_header("Content-Type: text/html; charset=ISO-8859-9\n\n");

Call before creating the object.

=head2 Password Regex

Passwords are checked with C<$CGI::Auth::Basic::RE> class variable.

=head1 ERROR HANDLING

Your script will die on any perl syntax error. But the API errors
are trapped by a private fatal error handler. If you do something 
illegal with the methods like; wrong number of parameters, or calling an 
undefined method, it'll be trapped by C<fatal handler>. Currently, you
can not control the behaviour of this method (unless you subclass it), 
but you can define it's HTTP Header; see L<fatal_header|/fatal_header>.
On any fatal error, it will print the error message and some usefull 
information as a web page, then it will terminate the program. You can
set the exit code with L<exit_code|/exit_code> method.

All error messages (including fatal) are accessible via the class variable 
C<%CGI::Auth::Basic::ERROR>. Dump this variable to see the keys and values.
If you want to change the error messages, do this before calling C<new()>.

=head1 EXAMPLES

See the 'eg' directory in the distribution. Download the distro from 
CPAN, if you don't have it.

=head1 CAVEATS

If you are using perl 5.5.3 and older on Win32 platform (this issue
may not be limited with Win32 but I'm not sure), you may need to 
install L<Crypt::UnixCrypt>. The C<CORE::crypt()> function is not 
implemented on this version.

=head1 BUGS

Contact the author if you find any.

=head1 SEE ALSO

L<CGI> and L<CGI::Auth>.

=head1 AUTHOR

Burak G�rsoy, E<lt>burakE<64>cpan.orgE<gt>

=head1 COPYRIGHT

Copyright 2004-2008 Burak G�rsoy. All rights reserved.

=head1 LICENSE

This library is free software; you can redistribute it and/or modify 
it under the same terms as Perl itself, either Perl version 5.8.8 or, 
at your option, any later version of Perl 5 you may have available.

=cut
