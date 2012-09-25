package LegendasTV;
use Moose;
use Modern::Perl;
use HTTP::Cookies;
use WWW::Mechanize;
use Term::ReadPassword;
extends qw(MooseX::App::Cmd);
# ABSTRACT: Base class for all commands

use constant COOKIE => "$ENV{HOME}/.legendas.tv.cookie";

has ua => (
   isa => 'WWW::Mechanize',
   is => 'ro',
   lazy => 1,
   builder => '_login',
);

our $VERSION = '1.00';

sub _login {
   my $self = shift;
   my $cookie = HTTP::Cookies->new(file => COOKIE, autosave => 1);
   my $logged = 0;
   $cookie->scan(sub {
      my ($key, $expires) = ($_[1], $_[8]);
      return unless $key eq 'Auth';
      $logged = ($expires > time ? 1 : 0);
   });
   my $ua = WWW::Mechanize->new(cookie_jar => $cookie);
   say ' * acessando legendas.tv';
   $ua->get('http://legendas.tv');
   unless ($logged) {
      say ' * entre com seu login e senha';
      print '   login: '; chomp(my $LOGIN = <STDIN>);
      my $PASSWORD = read_password('   senha: ');
      say ' * logando';
      $ua->submit_form(
         form_name   => 'form1',
         form_number => 1,
         fields      => { txtLogin => $LOGIN, txtSenha => $PASSWORD, chkLogin => 1 },
         button      => 'entrar',
      );
      $ua->follow_link( text_regex => qr/clique aqui caso/i );
   }
   return $ua;
}

=head1 NAME

LegendasTV - MooseX::App::Cmd base class

=head1 DESCRIPTION

LegendasTV provides a interface for http://legendas.tv site, a Brazilian
site for subtitles download.

=head1 AUTHOR

Joenio Costa <joenio@colivre.coop.br>

=head1 COPYRIGHT

Copyright (c) 2008-2012, Joenio Costa. All Rights Reserved.

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License version 3 as
published by the Free Software Foundation.

=cut

1;
