package LegendasTV::Command::logout;
use Moose;
use Modern::Perl;
extends qw(MooseX::App::Cmd::Command);
# ABSTRACT: clean cookies saved in cookie file

sub execute {
   my $self = shift;
   say ' * limpando cookie';
   $self->app->ua->cookie_jar->clear;
}

1;
