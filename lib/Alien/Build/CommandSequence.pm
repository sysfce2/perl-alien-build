package Alien::Build::CommandSequence;

use strict;
use warnings;
use Capture::Tiny qw( capture );
use Config ();

# ABSTRACT: Alien::Build command sequence
# VERSION

=head1 CONSTRUCTOR

=head2 new

 my $seq = Alien::Build::CommandSequence->new(@commands);

=cut

sub new
{
  my($class, @commands) = @_;
  my $self = bless {
    commands => \@commands,
  }, $class;
  $self;
}

=head1 METHODS

=head2 apply_requirements

 $seq->apply_requirements($meta, $phase);

=cut

sub apply_requirements
{
  my($self, $meta, $phase) = @_;
  my $intr = $meta->interpolator;
  foreach my $command (@{ $self->{commands} })
  {
    next if ref $command eq 'CODE';
    if(ref $command eq 'ARRAY')
    {
      foreach my $arg (@$command)
      {
        next if ref $arg eq 'CODE';
        $meta->add_requires($phase, $intr->requires($arg))
      }
    }
    else
    {
      $meta->add_requires($phase, $intr->requires($command));
    }
  }
  $self;
}

sub _run
{
  my(undef, @cmd) = @_;
  print "+@cmd\n";
  system @cmd;
  die "external command failed" if $?;
}

sub _run_with_code
{
  my($build, @cmd) = @_;
  my $code = pop @cmd;
  print "+@cmd\n";
  my %args = ( command => \@cmd );
  ($args{out}, $args{err}, $args{exit}) = capture {
    system @cmd; $?
  };
  print "[output consumed by Alien::Build]\n";
  $code->($build, \%args);
}

=head2 execute

 $seq->execute($build);

=cut

sub execute
{
  my($self, $build) = @_;
  my $intr = $build->meta->interpolator;

  my $prop = {
    alien => {
      install => $build->install_prop,
      runtime => $build->runtime_prop,
      meta    => $build->meta_prop,
    },
    perl    => {
      config => \%Config::Config,
    },
  };
  
  foreach my $command (@{ $self->{commands} })
  {
    if(ref($command) eq 'CODE')
    {
      $command->($build);
    }
    elsif(ref($command) eq 'ARRAY')
    {
      my($command, @args) = @$command;
      my $code = pop @args if $args[-1] && ref($args[-1]) eq 'CODE';
      ($command, @args) = map { $intr->interpolate($_, $prop) } ($command, @args);
      
      if($code)
      {
        _run_with_code $build, $command, @args, $code;
      }
      else
      {
        _run $build, $command, @args;
      }
    }
    else
    {
      my $command = $intr->interpolate($command,$prop);
      _run $build, $command;
    }
  }
}

1;