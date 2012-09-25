package LegendasTV::Command::search;
use Moose;
use Modern::Perl;
extends qw(MooseX::App::Cmd::Command);
# ABSTRACT: default search engine

=head1 NAME

LegendasTV::Command::search - default search engine

=cut

with 'LegendasTV::Roles::CommonParams';

has string => (
   traits => [qw(Getopt)],
   isa => 'Str',
   is  => 'rw',
   cmd_aliases   => 's',
   documentation => 'name of the movie to search',
   required => 1,
);

sub execute {
   my ($self, $opt, $args) = @_;
   say " * pesquisando ", $self->string;
   $self->app->ua->submit_form(
      form_name   => 'form1',
      form_number => 1,
      fields      => { txtLegenda => $self->string, selTipo => 1, int_idioma => $self->lang },
      button      => 'btn_buscar',
   );
   my $result = $self->app->ua->content;
   my @film = ();
   while ($result =~ m/<span onmouseover.*?gpop\('([^']+)','([^']+)','([^']+)','(\d+)','\d+','(\d+MB)',.*?abredown\('(\w+)'\)/sigo) {
      push @film, {filme => $1, descricao => $2, release => $3, cds => $4, size => $5, id => $6};
   }
   if (@film > 0) {
      say " * ", scalar(@film), " legenda(s) encontrada(s)";
   }
   else {
      say " * nenhuma legenda encontrada!";
      exit -1;
   }
   my $response = 's';
   while ($response eq 's') {
      for my $index (0 .. $#film) {
         my $n = $index + 1;
         say "\n ", $n, " $film[$index]->{release}";
         say "   $film[$index]->{filme} - $film[$index]->{descricao}";
         say "   tamanho: $film[$index]->{size}, cds: $film[$index]->{cds}";
      }
   
      print "\n   Selecione uma legenda para baixar: (q para sair) ";
      chomp(my $n = <STDIN>);
      last if $n eq 'q';
      my $index = $n - 1;
      say "\n * baixando legenda $film[$index]->{release}";
      $self->app->ua->get("http://legendas.tv/info.php?d=$film[$index]->{id}&c=1");
      say ' * arquivo ' . $self->app->ua->response->filename . ' salvo';
      $self->app->ua->save_content('./'. $self->app->ua->response->filename);
      print "\n   baixar outra legenda? (s/n)";
      chomp($response = <STDIN>);
   }
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
