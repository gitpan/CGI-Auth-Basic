#!/usr/bin/perl -w
use strict;
use CGI;
my $cgi  = CGI->new;

my $auth = TRAuth->new($cgi);
# $auth->set_template(delete_all => 1);
   $auth->check_user;
   $auth->screen(content => "Bu program� kullanabilirsiniz", 
                 title   => "Eri�im onayland�");

# Translate the interface to turkish
package TRAuth;
use CGI::Auth::Basic;

sub new {
   my $class = shift;
   my $cgi   = shift;
   CGI::Auth::Basic->fatal_header("Content-Type: text/html; charset=ISO-8859-9\n\n");
   %CGI::Auth::Basic::ERROR = error();
   my $auth = CGI::Auth::Basic->new(cgi_object     => $cgi, 
                                    file           => "./password.txt",
                                    http_charset   => 'ISO-8859-9',
                                    setup_pfile    => 1,
                                    logoff_param   => 'cik',
                                    changep_param  => 'parola_degistir',
                                    cookie_id      => 'parolakurabiyesi',
                                    cookie_timeout => '1h',
                                    chmod_value    => 0777,
                                    );

   $auth->set_template(template());
   $auth->set_title(title());
   return $auth;
}

sub template {
   return 
login_form => qq~

<span class="error"><?PAGE_FORM_ERROR?></span>
<form action="<?PROGRAM?>" method="post">

<table border="0" cellpadding="0" cellspacing="0">
 <tr><td class="darktable">
  <table border="0" cellpadding="4" cellspacing="1">
 <tr>
   <td class="titletable" colspan="3">Bu �zelli�i kullanabilmek i�in ba�lanmal�s�n�z</td>
 </tr>
 <tr>
  <td class="lighttable">Bu program� kullanmak i�in <i>gereken</i> parolay� girin:</td>
  <td class="lighttable"><input type="password" name="<?COOKIE_ID?>"></td>
  <td class="lighttable" align="right"><input type="submit" name="submit" value="Ba�lan"></td>
 </tr>
</table>
</td> </tr>
</table>
</form>
   ~,

change_pass_form => qq~
<span class="error"><?PAGE_FORM_ERROR?></span>
<form action="<?PROGRAM?>" method="post">

<table border="0" cellpadding="0" cellspacing="0">
 <tr><td class="darktable">
  <table border="0" cellpadding="4" cellspacing="1">
 <tr>
   <td class="titletable" colspan="3">
   3 ile 32 karakter aras�nda bir parola girin. Bo�luk kullanmay�n!</td>
 </tr>
 <tr>
  <td class="lighttable">Yeni parolan�z� girin:</td>
  <td class="lighttable"><input type="password" name="<?COOKIE_ID?>_new"></td>
  <td class="lighttable" align="right">
  <input type="submit" name="submit" value="Parolay� de�i�tir">
  <input type="hidden" name="change_password" value="ok"></td>
  <input type="hidden" name="<?CHANGEP_PARAM?>" value="1"></td>

 </tr>
</table>
</td> </tr>
</table>
</form>

~,

screen => qq~<html>
   <head>
    <?PAGE_REFRESH?>
    <title>CGI::Auth::Basic - T�rk�e >> <?PAGE_TITLE?></title>
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
      <?PAGE_LOGOFF_LINK?>
      <?PAGE_CONTENT?>
      <?PAGE_INLINE_REFRESH?>
   </body>
   </html>~,

   logoff_link => qq~
   <span class="small">[<a href="<?PROGRAM?>?<?LOGOFF_PARAM?>=1">��k</a>
   - <a href="<?PROGRAM?>?<?CHANGEP_PARAM?>=1">Parolay� de�i�tir</a>]</span> ~,

   ;
}

sub title {
return 
   login_form       => 'Ba�lan',
   cookie_error     => 'Ge�ersiz kurabiye',
   login_success    => 'Ba�lant� ba�ar�l�',
   logged_off       => '��k�� yapt�n�z',
   change_pass_form => 'Parolay� de�i�tir',
   password_created => 'Parola olu�turuldu',
   password_changed => 'Parola ba�ar�yla de�i�tirildi',
   error            => 'Hata',
   ;
}

sub error {
return 
   INVALID_OPTION    => "Se�enekler 'parametre => de�er' bi�iminde olmal�!",
   CGI_OBJECT        => "�al��mak i�in bir CGI nesnesine ihtiyac�m var!!!",
   FILE_READ         => "Parola dosyas� a��lam�yor: ",
   NO_PASSWORD       => "Herhangi bir parola belirtilmedi (veya parola dosyas� bulunam�yor)!",
   UPDATE_PFILE      => "Parola dosyan�z bo� ve ge�erli ayarlar�n�z bu kodun dosyay� g�ncellemesine izin vermiyor! L�tfen parola dosyan�z� g�ncelleyin.",
   ILLEGAL_PASSWORD  => "Ge�ersiz parola! Kabul edilmedi. Geri d�n�n ve yeni bir tane girin",
   FILE_WRITE        => "Parola dosyas� g�ncelleme i�in a��lam�yor: ",
   UNKNOWN_METHOD    => "'<b>%s</b>' ad�nda bir metod yok. Kodunuzu denetleyin.",
   EMPTY_FORM_PFIELD => "Herhangi bir parola ayarlamad�n�z (parola dosyas� bo�)!",
   WRONG_PASSWORD    => "<p>Yanl�� Parola!</p>",
   INVALID_COOKIE    => "Kurabiyeniz ge�ersiz bilgi i�eriyor ve bu kurabiye program taraf�ndan silindi.",
   ;
}
