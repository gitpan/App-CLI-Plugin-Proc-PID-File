package App::CLI::Plugin::Proc::PID::File;

=pod

=head1 NAME

App::CLI::Plugin::Proc::PID::File - for App::CLI::Extension pidfile plugin module

=head1 VERSION

0.1

=head1 SYNOPSIS

  # MyApp.pm
  package MyApp;
  
  use strict;
  use base qw(App::CLI::Extension);
  
  # extension method
  __PACKAGE__->load_plugins(qw(Proc::PID::File));
  
  # extension method
  __PACKAGE__->config( proc_pid_file => { verify => 1, dir => "/var/run", name => "myapp" } );
  
  1;
  
  # MyApp/Hello.pm
  package MyApp::Hello;
  use strict;
  use feature ":5.10.0";
  use base qw(App::CLI::Command);
  
  sub run {
  
      my($self, @args) = @_;
	  # make pid file (/var/run/myapp.pid)
	  # /var/run/myapp.pid is automatically deleted (by Proc::PID::File::DESTROY)
	  $self->pf->touch;
  }

=head1 DESCRIPTION

App::CLI::Extension pidfile plugin module

pf method setting

  __PACKAGE__->config( proc_pid_file => {%proc_pid_file_option} );

Proc::PID::File option is L<Proc::PID::File> please refer to

=cut

use strict;
use warnings;
use 5.008;
use base qw(Class::Data::Accessor);
use File::Basename;
use File::Path;
use Proc::PID::File;

__PACKAGE__->mk_classaccessor("pf");
our $VERSION = '0.1';

=pod

=head1 EXTENDED METHOD

=head2 Proc::PID::File::path

return pidfile path

Example:

  # MyApp::Hello(App::CLI::Command base package)
  sub run {

      my($self, @args) = @_;
      say $self->pf->path;
  }

=cut

*Proc::PID::File::path = \&_path;

=pod

=head1 METHOD

=head2 pf

return Proc::PID::File object. 

Specify the process ID of the file that describes the default Proc::PID::File in the specified or default values are applied, dir, name, but you may specify a combination of an optional extension to specify the pidfile possible.

--pidfile command line option if you also have to be defined by the specified module, --pidfile file path specified in the process ID can also be used as a file that describes the

Example1. Proc::PID::File pidfile config

 # in MyApp.pm
 __PACKAGE__->config(
                  proc_pid_file => {
                           pidfile => "/tmp/myapp.pid",
                           ###############################
                           # Following equivalent
                           ###############################
                           # dir   => "/tmp",
                           # name  => "myapp"
                  }
             );

Example2. pidfile option

  myapp --pidfile=/tmp/myapp.pid

=cut

sub setup {

	my $self = shift;
	my $pidfile;
    my %option = (exists $self->config->{proc_pid_file}) ? %{$self->config->{proc_pid_file}} : ();
	if (exists $option{pidfile} && defined $option{pidfile}) {
		$pidfile = $option{pidfile};
	}
	if (exists $self->{pidfile} && defined $self->{pidfile}) {
		$pidfile = $self->{pidfile};
	}

	if (defined $pidfile) {
		# get name and path. fileparse is File::Basename function
		my($name, $path) = fileparse($pidfile, qr/\.[^.]*$/);
		$option{name} = $name;
		$option{dir}  = $path;
	}

	# make directory. mkpath is File::Path function
	if (exists $option{dir} && !-d $option{dir}) {
		mkpath($option{dir});
	}

	$self->pf(Proc::PID::File->new(%option));
	return $self->NEXT::setup;
}

####################################
# Proc::PID::File extended method
####################################
sub _path {

	my $self = shift;
	return $self->{path};
}


1;
__END__

=head1 TIPS

=head2 MultiBoot Lock Plugin

1. Make MultiBoot Lock Plugin. require App::CLI::Plugin::InstallCallback

Example

  package MyApp::Plugin::MultiLauncherLock;
  
  use strict;
  use feature ":5.10.0";
  use FindBin qw($Script);
  
  sub setup {
  
      my $self = shift;
      $self->add_callback("prerun", \&_multi_launcher_lock);
  
      return $self->NEXT::setup;
  }
  
  sub _multi_launcher_lock {
  
      my $self = shift;
      if ($self->pf->alive) {
          my $pid = $self->pf->read;
          say "already $Script\[$pid\] is running";
          exit 1;
      }
      $self->pf->touch;
  }
  
  1;

2. Load MyApp::Plugin::MultiLauncherLock

  # in MyApp.pm
  __PACKAGE__->load_plugins(qw(
              InstallCallback
              Proc::PID::File
              +MyApp::Plugin::MultiLauncherLock
            ));

3. Make MyApp::Run

Example

  package MyApp::Run;
  
  use strict;
  use feature ":5.10.0";
  
  sub run {
  
      my($self, @args) = @_;
	  sleep 60;
	  say "end";
  }

4. first execute

  # 60 seconds after the "end" to exit and output
  myapp run

5. second execute
first execute run to run the same script again before the end of the

  myapp run

Running a dual 2 "already myapp [$pid] is running" is output, and end with exit code 1


=head2 Old Process Killing Plugin

Example

  package MyApp::Plugin::OldProcessKill;
  
  use strict;
  use feature ":5.10.0";
  use FindBin qw($Script);
  use POSIX qw(SIGTERM SIGINT SA_RESTART sigaction);
  
  sub setup {
  
      my $self = shift;
      $self->add_callback("prerun", \&_old_process_kill);
  
      return $self->NEXT::setup;
  }
  
  sub _old_process_kill {
  
      my $self = shift;
	  
      my $set = POSIX::SigSet->new(SIGTERM, SIGINT);
      my $act = POSIX::SigAction->new(sub {
                                      my $signal = shift;
                                      say "signal $signal recevied...";
                                      exit 1;
                                  }, $set, SA_RESTART);
      my $old_act = POSIX::SigAction->new;
      sigaction(SIGTERM, $act, $old_act);
      sigaction(SIGINT, $act, $old_act);
      if ($self->pf->alive) {
          my $pid = $self->pf->read;
          kill SIGTERM, $pid;
          say "old process $Script\[$pid\] is killed";
      }
      $self->pf->touch;
  }
  
  1;

2. Load MyApp::Plugin::OldProcessKill

  # in MyApp.pm
  __PACKAGE__->load_plugins(qw(
              InstallCallback
              Proc::PID::File
              +MyApp::Plugin::OldProcessKill
            ));

3. Make MyApp::Run

Example

  package MyApp::Run;
  
  use strict;
  use feature ":5.10.0";
  
  sub run {
  
      my($self, @args) = @_;
	  sleep 60;
	  say "end";
  }

4. first execute

  # 60 seconds after the "end" to exit and output
  myapp run

5. second execute
first execute run to run the same script again before the end of the

  myapp run
  old process myapp[9999] is killed

first execute process is killed and dying message "signal TERM recevied..."

=head1 SEE ALSO

L<App::CLI::Extension> L<NEXT> L<Proc::PID::File>

=head1 AUTHOR

Akira Horimoto

=head1 COPYRIGHT AND LICENSE

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

Copyright (C) 2009 Akira Horimoto

=cut

