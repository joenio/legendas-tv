package LegendasTV::Command::logout;
use Moose;
use Modern::Perl;
extends qw(MooseX::App::Cmd::Command);
# ABSTRACT: clear credentials saved in cookie file

=head1 NAME

LegendasTV::Command::logout - clear credentials saved in cookie file

=cut

sub execute {
   my $self = shift;
   say ' * limpando cookies';
   $self->app->ua->cookie_jar->clear;
}

=head1 AUTHOR

Joenio Costa <joenio@colivre.coop.br>

=head1 COPYRIGHT

Copyright (c) 2008-2012, Joenio Costa. All Rights Reserved.

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License version 3 as
published by the Free Software Foundation.

=cut

1;
