package LegendasTV::Command::psearch;
use Moose;
use Modern::Perl;
extends qw(MooseX::App::Cmd::Command);
# ABSTRACT: power search engine (experimental)

=head1 NAME

LegendasTV::Command::psearch - power search engine (experimental)

=cut

with 'LegendasTV::Roles::CommonParams';

use File::Basename;
use File::Copy;
use Archive::Extract;
use Archive::Rar;
use File::Find::Rule;

use constant LEGENDAS_TYPE_MOVIE => 1;
use constant LEGENDAS_TYPE_TV => 1;
use constant TMP_EXTRACT => "/tmp/legendas/extract/"; # Careful! should be an exclusive directory!
use constant TMP => "/tmp/legendas/"; # Directory to drop the compacted files from legendas.tv

has file => (
   traits => [qw(Getopt)],
   isa => 'Str',
   is  => 'rw',
   cmd_aliases   => 'f',
   documentation => 'file name',
   required => 1,
);

has dir => (
   traits => [qw(Getopt)],
   isa => 'Str',
   is  => 'rw',
   cmd_aliases   => 'd',
   documentation => 'directory name', 
   required => 1,
);

has ignore => (
   traits => [qw(Getopt)],
   isa => 'Bool',
   is  => 'rw',
   cmd_aliases   => 'i',
   documentation => 'ignora arquivos que ja possuem legenda',
);

has noauto => (
   traits => [qw(Getopt)],
   isa => 'Bool',
   is  => 'rw',
   documentation => 'não faz buscas automáticas',
);

sub execute {
   my $self = shift;
   $self->create_temp_dir;
   $self->search_subtitle($self->file);
   $self->search_files;
   $self->remove_temp_dir;
}

sub create_temp_dir {
   my $self = shift;
   unless (-e TMP) {
      mkdir TMP;
   }
   unless (-e TMP_EXTRACT) {
      mkdir TMP_EXTRACT;
   }
}

sub remove_temp_dir {
   my $self = shift;
   rmdir TMP_EXTRACT;
}

sub search_files {
   my $self = shift;
   my $yes_to_all = $self->quiet;
   my $option = '';

   unless (-d $self->dir && -r $self->dir) {
      say ' * ' . $self->dir . " doesn't exist or isn't readable.";
   }
   else {
      my @files = File::Find::Rule->file()->name( qr/\.(avi|mkv|mp4)$/i )->in( $self->dir );
      if (scalar @files > 0) {
         say ' * ' , scalar(@files) , ' files found while searching ' , $self->dir;

         foreach my $file ( @files ) {
            $option = "";
            if ($self->ignore) {
               my $subtitle_file = $file;
               $subtitle_file =~ s/\.(avi|mkv|mp4)$//i;
               $subtitle_file .= ".srt";
               if (-e $subtitle_file) {
                  say " * Ignoring file " , $file , ". Subtitle found.";
                  next;
               }
            }

            unless ( $yes_to_all ) {
               print "\n";
               until ( $option =~ m/(y|n|a|q)/i ) {
                  print "   Search subtitles for (" . $file . ")? (y/n/a/q) ";
                  chomp( $option = <STDIN> );
               }
            }
            else {
               $option = "y";
            }

            if ( $option =~ m/a/i ) {
               $yes_to_all = 1;
            }

            if ( $option =~ m/y/i || $yes_to_all || $option eq '' ) {
               $self->search_subtitle( $file );
            }
            last if $option =~ m/q/i;
         }
      }
   }
}

sub search_subtitle {
   my $self = shift;
   my $file = shift;
   unless ( -e $file ) {
      say ' * ' . $file . ' doesn\'t exist.';
      return 0;
   }

   if ( $file =~ m/\.(=?avi|mkv|mp4)$/gis ) {
      my $is_tv_series = $self->define_subtitle_type( $file );
      my @queries = ();
      my $selected_file = "";

      say " * Searching subtitles for " , $file;

      if ( $is_tv_series ) {
         # try to extract tv series metadata
         my ( $series_name , $series_episode , $series_release ) = $self->parse_tv_metadata( basename( $file ) );
         if ( defined $series_name && length $series_name > 0 ) {
            $queries[scalar @queries] = "$series_name $series_episode $series_release";
            $queries[scalar @queries] = "$series_name $series_episode";
         }
      }
      else {
         my ( $movie_name , $movie_year , $movie_release ) = $self->parse_movie_metadata( $file );
         if ( defined $movie_name && length $movie_name > 0 ) {
            $queries[scalar @queries] = "$movie_name $movie_year $movie_release";
            $queries[scalar @queries] = "$movie_name $movie_year";
            $queries[scalar @queries] = "$movie_name $movie_release";
         }
      }

      my $ask_query = 0;
      unless ( $self->noauto ) {
         say ' * Query options: ' . join( ', ' , @queries );
         foreach my $query ( @queries ) {
            $selected_file = $self->query_engine( $self->trim( $query ) , $is_tv_series ? LEGENDAS_TYPE_TV : LEGENDAS_TYPE_MOVIE , $file );
            if ( length $selected_file && -e $selected_file ) {
               last;
            }
         }
      }
      else{
         $ask_query = 1;
      }

      while ( length( $selected_file ) == 0 && ! $self->quiet ) {
         my $response = 'y';
         unless ( $ask_query ) {
            print "\n   Try again with another query? (y/N) ";
            chomp( $response = <STDIN>);
            $ask_query = 0;
         }

         if ( $response =~ /y/i ) {
            print "   Query (empty to cancel): ";
            chomp( my $query = <STDIN>);
            print "\n";

            $selected_file = $self->query_engine( $query , $is_tv_series ? LEGENDAS_TYPE_TV : LEGENDAS_TYPE_MOVIE , $file );
            if ( length( $selected_file ) > 0 || length( $query ) == 0 ) {
               last;
            }
         }
         else {
            last;
         }
      }

      if ( length $selected_file && -e $selected_file ) {
         $file =~ s/\.(avi|mkv|mp4)$/.srt/i;
         move( $selected_file , $file );
         say " * Moving $selected_file to $file";
      }
   }
   else {
      say ' * ' . $file . ' is not a valid media file. Media files should have mkv, avi or mp4 extension.';
   }
}

sub extract_recursively {
   my $self = shift;
   my $file = shift;
   my $files = shift;
   my @tmp_files = ();

   chdir( TMP_EXTRACT ); # cant set path to extract files on archive::rar... 
   if ( $file =~ m/\.rar$/is ) {
      my $archive = Archive::Rar->new( -archive => $file , -quiet => 1 );
      $archive->Extract();
   }
   else {
      my $archive = Archive::Extract->new( archive => $file );
      $archive->extract( to => TMP_EXTRACT );
   }
   @tmp_files = File::Find::Rule->file()->name( "*.*" )->in( TMP_EXTRACT );
   chdir( '-' ) ; # returns to my old directory

   foreach my $f (@tmp_files) {
      if ( $f =~ m/\.rar$/is || $f =~ m/\.zip$/is ) {
         $self->extract_recursively( $f , \@$files );
      }
      unless ( $f =~ m/\.srt/is ) {
         unlink $f;
      }
      else{
         my $skip = 0;
         foreach (@$files) {
            $skip++ if $_ eq $f;
         }
         @$files[scalar @$files] = $f unless $skip;
      }
   }
}

sub handle_archive {
   my $self = shift;
   my $archive = shift;
   my $media_file = shift;
   my @files = ();
   my $selected = "";

   foreach my $file (@$archive) {
      $self->extract_recursively( $file , \@files );
   }
   
   $media_file = basename( $media_file );
   $media_file =~ s/\.(avi|mp4|mkv)$//gis;
   $media_file =~ s/\./ /gis;
   
   my $index = "";
   if ( $#files > 1 ) {
      say ' * Searching';
   
      while ( 1 ) {
         print "\n";
         my $suggestion_index = -1;
         for my $index (0..$#files) {
            my $suggestion = "  $index  ";
            my $comp_file = basename( $files[$index] );
            $comp_file =~ s/\.[a-z]+$//gis;
            $comp_file =~ s/\./ /gis;
   
            if ( lc $media_file eq lc $comp_file && $suggestion_index == -1 ) {
               $suggestion = " *" . $index . "* ";
               $suggestion_index = $index;
            }
            say $suggestion , basename( $files[$index] );
         }
         print "\n";
   
         unless ( $self->quiet ) {
            if ( $suggestion_index > -1 ) {
               print "\n   " . $#files . " files found; choose the appropriate file number or <enter> to suggested file: ";
            }
            else {
               print "\n   " . $#files . " files found; choose the appropriate file number: ";
            }
   
            chomp($index = <STDIN>);
            print "\n";
         }
   
         if ( $index eq "" && $suggestion_index > -1 ) {
            $index = $suggestion_index;
         }
   
         if ( ! $self->quiet ) {
            if ( $index =~ m/[^0-9]+/is || !defined $files[$index] ) {
               print "   Abort? (Y/n)\n";
               chomp($index = <STDIN>);
               print "\n";
               if ( $index eq "" || $index =~ m/y/i ) {
                  last;
               }
            }
            else{
               last;
            }
         }
         else{
            last;
         }
      }
   }

   $selected = $files[$index] if $index =~ m/[0-9]+/is && defined $files[$index];
   foreach my $file ( @files ) {
      unlink $file if ( $selected ne $file );
   }
   $selected = $selected if length $selected;
   return $selected;
}

sub query_engine {
   my $self = shift;
   my $query = shift;
   my $media_type = shift;
   my $file = shift;

   return if length $query == 0;

   say " * Querying $query";
   $self->app->ua->submit_form(
      form_name   => 'form1',
      form_number => 1,
      fields      => { txtLegenda => $query, selTipo => $media_type , int_idioma => $self->lang },
      button      => 'btn_buscar',
   );

   my $result = $self->app->ua->content;

   my @film = ();
   while ($result =~ m/<span onmouseover.*?gpop\('([^']+)','([^']+)','([^']+)','(\d+)','\d+','(\d+MB)',.*?abredown\('(\w+)'\)/sigo) {
      push @film, {filme => $1, descricao => $2, release => $3, cds => $4, size => $5, id => $6};
   }

   unless (@film > 0) {
      say " * no subtitle found!";
      return "" ;
   }

   my @archives = ();
   for my $index (0 .. $#film) {
      $self->app->ua->get("http://legendas.tv/info.php?d=$film[$index]->{id}&c=1");
      $self->app->ua->save_content( TMP . $self->app->ua->response->filename );
      $archives[$index] = TMP . $self->app->ua->response->filename;
   }

   while ( 1 ) {
      my $selected_file = $self->handle_archive( \@archives , $file );
      if ( $selected_file ne '' ) {
         unless ( $self->quiet ) {
            print "   Is this the correct subtitle ($selected_file)? (Y/n)";
            chomp( my $n = <STDIN> );
            print "\n" ;
            if ( $n =~ m/n/i ) {
               next;
            }
         }
      }
      else{
         say " * no subtitle found!";
      }
      foreach my $archive (@archives) {
         unlink $archive;
      }
      return $selected_file;
   }	
}

sub parse_tv_metadata {
   my $self = shift;
   my $filename = shift;
   my $name = "";
   my $episode = "";
   my $release = "";

   if ( $filename =~ m/(.+)[\.\s](s[0-9][0-9]e[0-9][0-9]).+/gis ) {
      $name = $1;
      $episode = $2;
   }
   if ( $filename =~ m/[-\.]([a-z]+)\.[^\.]+$/is ) {
      $release = $1;
   }
   return ( $name , $episode , $release );
}

sub parse_movie_metadata {
   my $self = shift;
   my $file = shift;
   $file =~ s/\.(=?avi|mkv|mp4)//gis; # remove file extension
   my $filename = basename( $file );
   my $name = "";
   my $year = "";
   my $release = "";

   if ( $filename =~ m/(.+[\s\.])+\(?([1-2][0-9][0-9][0-9])\)?/gis ) { # get everything until movie year is found
      $name = $1;
      $year = $2;
   }
   elsif ( $filename =~ m/(.+[\s\.])+(?=720p|1080p|DVDrip|HDrip|BRrip|BDrip)/gis ) { # get everything until movie year is found
      # if the movie doesn't have a year, then it should have the format, perhaps
      $name = $1;
   }

   $name =~ s/\.$//is;
   $name =~ s/\./ /is;

   if ( $filename =~ m/[\-\.]([a-z]+)$/gis ) {
      $release = $1;
   }

   unless ( length $name ) {
      $file =~ s/$filename//gis;
      if ( $file =~ m/\/(.+?)\/$/gis ) {
         return $self->parse_movie_metadata( $1 );
      }
   }
   return ( $name , $year , $release );
}

sub define_subtitle_type {
   my $self = shift;
   my $filename = shift;
   return $filename =~ m/.*s[0-9][0-9]e[0-9][0-9].*/gis; # tv series commom signature
}

sub trim {
   my $self = shift;
   my $s = shift;
   $s =~ s/^\s+//gis;
   $s =~ s/\s+$//gis;
   return $s;
}

=head1 AUTHOR

Fernando Nemec <fernando.nemec@grupofolha.com.br>

=head1 COPYRIGHT

Copyright (c) 2012, Fernando Nemec. All Rights Reserved.

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License version 3 as
published by the Free Software Foundation.

=cut

1;
