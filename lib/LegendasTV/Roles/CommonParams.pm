package LegendasTV::Roles::CommonParams;
use Moose::Role;

has username => (
   traits => [qw(Getopt)],
   isa => 'Str',
   is  => 'rw',
   cmd_aliases   => 'u',
   documentation => 'username to login in legendas.tv site',
);

has password => (
   traits => [qw(Getopt)],
   isa => 'Str',
   is  => 'rw',
   cmd_aliases   => 'p',
   documentation => 'password to login in legendas.tv site',
);

use constant PT_BR => 1;
use constant EN    => 2;
use constant ES    => 3;
use constant PT    => 10;
use constant ALL   => 99;
use constant OTHER => 100;

has lang => (
   traits => [qw(Getopt)],
   isa => 'Int',
   is  => 'rw',
   cmd_aliases   => 'l',
   documentation => 'language of subtitle to search',
   default => PT_BR,
);

sub quiet {
   my $self = shift;
   $self->username && $self->password;
}

1;
