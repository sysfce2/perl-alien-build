package Alien::Build::Plugin::Build::Autoconf;

use strict;
use warnings;
use Alien::Build::Plugin;
use constant _win => $^O eq 'MSWin32';
use Path::Tiny ();

# ABSTRACT: Autoconf plugin for Alien::Build
# VERSION

=head1 SYNOPSIS

 use alienfile;
 plugin 'Build::Autoconf' => ();

=head1 DESCRIPTION

This plugin provides some tools for building projects that use autoconf.  The main thing
this provides is a C<configure> helper, documented below and the default build stage,
which is:

 '%{configure} --prefix=%{alien.install.autoconf_prefix} --disable-shared',
 '%{make}',
 '%{make} install',

On Windows, this plugin also pulls in the L<Alien::Build::Plugin::Build::MSYS> which is
required for autoconf style projects on windows.

The other thing that this plugin does is that it does a double staged C<DESTDIR> install.
The author has found this improves the overall reliability of L<Alien> modules that are
based on autoconf packages.

=head1 PROPERTIES

=head2 with_pic

Adds C<--with-pic> option when running C<configure>.  If supported by your package, it
will generate position independent code on platforms that support it.  This is required
to XS modules, and generally what you want.

autoconf normally ignores options that it does not understand, so it is usually a safe
and reasonable default to include it.  A small number of projects look like they use
autoconf, but are really an autoconf style interface with a different implementation.
They may fail if you try to provide it with options such as C<--with-pic> that they do
not recognize.  Such packages are the rationale for this property.

=cut

has with_pic       => 1;
#has dynamic        => 0; # TODO

sub init
{
  my($self, $meta) = @_;
  
  require Alien::Build::Plugin::Build::MSYS;
  Alien::Build::Plugin::Build::MSYS->new->init($meta);
  
  $meta->prop->{destdir} = 1;
  $meta->prop->{autoconf} = 1;
  
  my $intr = $meta->interpolator;

  $meta->around_hook(
    build => sub {
      my $orig = shift;
      my $build = shift;

      my $prefix = $build->install_prop->{prefix};
      if(_win)
      {
        $prefix = Path::Tiny->new($prefix)->stringify;
        $prefix =~ s!^([a-z]):!/$1!i if _win;
      }
      $build->install_prop->{autoconf_prefix} = $prefix;

      my $ret = $orig->($build, @_);

      if(_win)
      {
        my $real_prefix = Path::Tiny->new($build->install_prop->{prefix});
        my $pkgconf_dir = Path::Tiny->new($ENV{DESTDIR})->child($prefix)->child('lib/pkgconfig');
      
        # for any pkg-config style .pc files that are dropped, we need
        # to convert the MSYS /C/Foo style paths to C:/Foo
        if(-d $pkgconf_dir)
        {
          foreach my $pc_file ($pkgconf_dir->children)
          {
            $pc_file->edit(sub {s/\Q$prefix\E/$real_prefix->stringify/eg;});
          }
        }
      }
      
      $ret;
    },
  );

=head1 HELPERS

=head2 configure

 %{configure}

The correct incantation to start an autoconf style C<configure> script on your platform.
Some reasonable default flags will be provided.

=cut

  $intr->add_helper(
    configure => sub {
      my $configure = _win ? 'sh configure' : './configure';
      $configure .= ' --with-pic' if $self->with_pic;
      $configure;
    },
  );
  
  $meta->default_hook(
    build => [
      '%{configure} --prefix=%{alien.install.autoconf_prefix} --disable-shared',
      '%{make}',
      '%{make} install',
    ]
  );
  
  $self;
}

1;

=head1 SEE ALSO

L<Alien::Build::Plugin::MSYS>, L<Alien::Build::Plugin>, L<Alien::Build>, L<Alien::Base>, L<Alien>

L<https://www.gnu.org/software/autoconf/autoconf.html>

L<https://www.gnu.org/prep/standards/html_node/DESTDIR.html>

=cut