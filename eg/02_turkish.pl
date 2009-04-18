#!/usr/bin/perl -w
use strict;
use CGI;
my $cgi  = CGI->new;

my $auth = TRAuth->new($cgi);
# $auth->set_template(delete_all => 1);
   $auth->check_user;
   $auth->screen(content => "Bu programý kullanabilirsiniz", 
                 title   => "Eriþim onaylandý");

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
   <td class="titletable" colspan="3">Bu özelliði kullanabilmek için baðlanmalýsýnýz</td>
 </tr>
 <tr>
  <td class="lighttable">Bu programý kullanmak için <i>gereken</i> parolayý girin:</td>
  <td class="lighttable"><input type="password" name="<?COOKIE_ID?>"></td>
  <td class="lighttable" align="right"><input type="submit" name="submit" value="Baðlan"></td>
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
   3 ile 32 karakter arasýnda bir parola girin. Boþluk kullanmayýn!</td>
 </tr>
 <tr>
  <td class="lighttable">Yeni parolanýzý girin:</td>
  <td class="lighttable"><input type="password" name="<?COOKIE_ID?>_new"></td>
  <td class="lighttable" align="right">
  <input type="submit" name="submit" value="Parolayý deðiþtir">
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
    <title>CGI::Auth::Basic - Türkçe >> <?PAGE_TITLE?></title>
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
   <span class="small">[<a href="<?PROGRAM?>?<?LOGOFF_PARAM?>=1">Çýk</a>
   - <a href="<?PROGRAM?>?<?CHANGEP_PARAM?>=1">Parolayý deðiþtir</a>]</span> ~,

   ;
}

sub title {
return 
   login_form       => 'Baðlan',
   cookie_error     => 'Geçersiz kurabiye',
   login_success    => 'Baðlantý baþarýlý',
   logged_off       => 'Çýkýþ yaptýnýz',
   change_pass_form => 'Parolayý deðiþtir',
   password_created => 'Parola oluþturuldu',
   password_changed => 'Parola baþarýyla deðiþtirildi',
   error            => 'Hata',
   ;
}

sub error {
return 
   INVALID_OPTION    => "Seçenekler 'parametre => deðer' biçiminde olmalý!",
   CGI_OBJECT        => "Çalýþmak için bir CGI nesnesine ihtiyacým var!!!",
   FILE_READ         => "Parola dosyasý açýlamýyor: ",
   NO_PASSWORD       => "Herhangi bir parola belirtilmedi (veya parola dosyasý bulunamýyor)!",
   UPDATE_PFILE      => "Parola dosyanýz boþ ve geçerli ayarlarýnýz bu kodun dosyayý güncellemesine izin vermiyor! Lütfen parola dosyanýzý güncelleyin.",
   ILLEGAL_PASSWORD  => "Geçersiz parola! Kabul edilmedi. Geri dönün ve yeni bir tane girin",
   FILE_WRITE        => "Parola dosyasý güncelleme için açýlamýyor: ",
   UNKNOWN_METHOD    => "'<b>%s</b>' adýnda bir metod yok. Kodunuzu denetleyin.",
   EMPTY_FORM_PFIELD => "Herhangi bir parola ayarlamadýnýz (parola dosyasý boþ)!",
   WRONG_PASSWORD    => "<p>Yanlýþ Parola!</p>",
   INVALID_COOKIE    => "Kurabiyeniz geçersiz bilgi içeriyor ve bu kurabiye program tarafýndan silindi.",
   ;
}
