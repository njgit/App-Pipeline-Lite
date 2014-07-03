use strict;
use warnings;
package App::Pipeline::Lite4::Base;
use Moo;
use MooX::late;
use Path::Tiny;
use Types::Path::Tiny qw/Path AbsPath/;
use Config::Tiny;
use Ouch;
use File::HomeDir; 
use Data::Table;
use App::Pipeline::Lite4::Logger; 
use List::Util qw(max);

has pipeline_dir  => ( isa => Path,  is => 'rw', coerce => 1, trigger  => \&_pipeline_dir_trigger);
has use_relative_paths  => (isa => 'Bool', is => 'rw', default => sub {0});
has pipeline_name    => ( isa => 'Str', is => 'rw', lazy_build => 1);
has pipeline_file    => ( isa => Path, is => 'rw',  lazy_build => 1);
has logfile          => ( isa => Path, is => 'rw', lazy_build => 1);
has logconf          => ( isa => 'HashRef|Undef', is => 'rw', lazy_build => 1);
has logconffile      => ( isa => Path, is => 'rw',  lazy_build => 1);
has logger           => ( isa => 'App::Pipeline::Lite4::Logger', lazy_build=>1);
has system_logfile   => ( isa => Path, is => 'rw',  lazy_build => 1);
has system_logger    => ( isa => 'App::Pipeline::Lite4::Logger', lazy_build=>1);
# config locations

has config           => ( isa => 'Config::Tiny', is => 'rw', lazy_build => 1 );
has config_file      => ( isa => Path, is => 'rw', coerce => 1, lazy_build => 1);
has system_config      => (isa => 'Config::Tiny', is => 'rw', lazy_build => 1 ); 
has system_config_file => ( isa => Path, is => 'rw', coerce => 1, lazy_build => 1);

=cut
has logconffile      => ( isa => Path, is => 'rw',  lazy_build => 1);
=cut

has output_dir       => ( isa => Path, is => 'rw',  coerce => 1,  lazy_build => 1 );
has input_dir        => ( isa => Path, is => 'rw',  coerce => 1,  lazy_build =>1  );
has software_dir     => ( isa => Path, is => 'rw',  coerce => 1,  lazy_build =>1  );
has software_ini      => (isa => 'Config::Tiny', is => 'rw', lazy_build => 1 );
has software_ini_file => ( isa => Path, is => 'rw',  coerce => 1,  lazy_build =>1  );
has test_data_file   => ( isa => Path, is => 'rw', coerce => 1,  lazy_build =>1  );
has datasource_file  => ( isa => Path, is => 'rw', coerce => 1,  lazy_build =>1  );
has datasource_resolved_file  => ( isa => Path, is => 'rw', coerce => 1,  lazy_build =>1  );
 
has pipeline_preparse_file => (isa => Path, is => 'rw', coerce => 1, lazy_build => 1 ); 
has pipeline_parse_file => (isa => Path, is => 'rw', coerce => 1, lazy_build => 1 ); 
has pipeline_resolved_file => (isa => Path, is => 'rw', coerce => 1, lazy_build => 1 ); 
has pipeline_graph_file => (isa => Path, is => 'rw', coerce => 1, lazy_build => 1 );
has pipeline_submission_file => (isa => Path, is => 'rw', coerce => 1, lazy_build => 1 );
has pipeline_datasource  => ( isa => 'Data::Table', is => 'rw', lazy_build =>1 ); #used in util.

has symlink_dir => ( isa => Path, is => 'rw',  coerce => 1,  lazy_build => 1 );
has output_run_name => (  isa => 'Str', is => 'rw', default => sub {return 'run'} );
has output_job_name => (  isa => 'Str', is => 'rw', default => sub {return 'job'} );
has run_settings_name => ( isa => 'Str', is => 'rw', default => sub {return 'settings'});

has run_num => ( isa => 'Str', is => 'rw'); 
has job_filter_str  => ( isa => 'Str|Undef', is => 'rw');
has step_filter_str => ( isa => 'Str|Undef', is => 'rw');
has argument_str    => ( isa => 'Str|Undef', is => 'rw'  );


sub _pipeline_dir_trigger {
    my $self = shift;
    return if $self->pipeline_dir->is_absolute;
    if ($self->use_relative_paths){
        warn "USING RELATIVE PATHS";
        warn "The pipeline_dir is relative " if $self->pipeline_dir->is_relative;
        warn "But the pipeline_dir is absolute" if $self->pipeline_dir->is_absolute;
    } else {
       $self->pipeline_dir( $self->pipeline_dir->absolute );
    }
}

sub _build_pipeline_name {
    my $self = shift;
    return $self->pipeline_dir->basename; 
}

sub _build_pipeline_file {
    my $self = shift;
    return path( $self->pipeline_dir, $self->pipeline_name . '.pipeline' ); 
}

sub _build_pipeline_preparse_file {
    my $self = shift;
    return path( $self->pipeline_dir, $self->pipeline_name . '.preparse.yaml') ; 
}

sub _build_pipeline_parse_file {
    my $self = shift;
    return path( $self->pipeline_dir, $self->pipeline_name . '.parse.yaml') ; 
}

sub _build_pipeline_resolved_file {
    my $self = shift;
    return path( $self->pipeline_dir, $self->pipeline_name . '.resolved.yaml') ; 
}

sub _build_pipeline_graph_file {
    my $self = shift;
    return path( $self->pipeline_dir, $self->pipeline_name . '.graph.yaml') ; 
}

sub _build_pipeline_submission_file {
    my $self = shift;
    return path( $self->pipeline_dir, $self->pipeline_name . '.submissions.txt') ; 
}

sub _build_pipeline_datasource {
    my $self = shift;
    my $datasourcefile = path( $self->datasource_file )->absolute;    
    ouch 'badfile', "Need to provide datasource file location\n" unless defined( $datasourcefile);
    #my $t =  App::Pipeline::Lite2::Datasource->new( datasource_file => $datasourcefile );         
    my $t = Data::Table::fromTSV( $datasourcefile->stringify );
}

sub _build_logfile {
    my $self = shift;
    #return file($self->pipeline_dir, $self->pipeline_name .".log")->stringify;
    #this should be able to be set system/user wide
    my $tmp_dir = "/tmp/";
    return path($tmp_dir, $self->pipeline_name .".log") #->stringify;
}

sub _build_system_logfile {
    my $self = shift;
    #return file($self->pipeline_dir, $self->pipeline_name .".log")->stringify;
    #this should be able to be set system/user wide
    my $sys_log_dir = File::HomeDir->my_data;
    return path($sys_log_dir, "plite.log"); #->stringify;
}

sub _build_software_ini_file {
   my $self = shift;  
   my $file = path($self->software_dir, 'software.ini');
   return $file;
}

sub _build_software_ini {
    my $self = shift;
    my $cf = Config::Tiny->new;
    #if no config file then means nothing has been set.
    return $cf unless $self->software_ini_file->exists;
    my $conf = $cf->read( $self->software_ini_file->absolute->stringify ) or ouch 'badfile' , "Cannot read config file ".$cf->errstr; 
    return $conf;
}

sub _build_logger {
    my $self = shift;   
    my $logger = App::Pipeline::Lite4::Logger->new( logfile => $self->logfile) ;    
    return $logger; 
}

sub _build_system_logger {
    my $self = shift;
    my $logger = App::Pipeline::Lite4::Logger->new( logfile => $self->system_logfile) ;    
    return $logger;
}

sub _build_logconf {
    my $self = shift;
    # open YAML config file
     my $logconf_yaml =  $self->logconffile->stat
      ? $self->logconffile->slurp
      : return undef;
    my $logconfig = Load($logconf_yaml);
    return $logconfig;
}

sub _build_logconffile {
    my $self = shift;
    return path( $self->pipeline_dir, $self->pipeline_name . '.log.conf' );
}

sub _build_config_file {
   my $self = shift;  
   my $file = path($self->pipeline_dir, $self->pipeline_name.'.ini');
   #print "config file is $file\n";
   #$file->touch;
   return $file;
}

sub _build_config {
    my $self = shift;
    my $cf = Config::Tiny->new;
    #if no config file then means nothing has been set.
    return $cf unless $self->config_file->exists;
    my $conf = $cf->read( $self->config_file ) 
       or ouch 'badfile' , "Cannot read config file ".$cf->errstr; 
    return $conf;
}

sub _build_system_config {
    my $self = shift;
    my $cf = Config::Tiny->new;
    #if no config file then means nothing has been set.
    return $cf unless $self->system_config_file->exists;
    my $conf = $cf->read( $self->system_config_file ) or ouch 'badfile' , "Cannot read config file ".$cf->errstr; 
    return $conf;
}

sub _build_system_config_file {
   my $self = shift;  
   my $system_config_dir = File::HomeDir->my_dist_config('App-Pipeline-Lite4', { create => 1 });
   my $system_config_file = path($system_config_dir, 'config.ini');
   #print "config file is $file\n";
   #$file->touch;
   return $system_config_file;
}

sub _build_output_dir {
    my $self = shift;
    my $output_dir = $self->config->{_}->{output_dir}; 
    return path($output_dir) if(defined( $output_dir)) ;
    return path( $self->pipeline_dir, 'output'  ); 
}

sub _build_input_dir {
    my $self = shift;
    my $input_dir = $self->config->{_}->{input_dir}; 
    return path($input_dir) if(defined( $input_dir)) ;
    return path( $self->pipeline_dir, 'input'  ); 
}


sub _build_symlink_dir {
    my $self = shift;
    my $symlink_dir = $self->config->{_}->{symlink_dir}; 
    return path($symlink_dir) if(defined( $symlink_dir)) ;
    return path( $self->pipeline_dir, 'symlink'  ); 
}


sub _build_software_dir {
    my $self = shift;
    my $software_dir = $self->config->{_}->{software_dir}; 
    return path($software_dir) if(defined( $software_dir)) ;
    return path( $self->pipeline_dir, 'software'  ); 
}

sub _build_datasource_file {
    my $self = shift;
    return path( $self->pipeline_dir, $self->pipeline_name . '.datasource');
}

sub _build_datasource_resolved_file {
    my $self = shift;
    return path( $self->pipeline_dir, $self->pipeline_name . '.resolved.datasource');
}

sub _build_test_data_file {
    my $self = shift;
    return path( $self->pipeline_dir, 'test_data', 'test.txt'  ); 
}

sub run_dir  {
    my $self = shift;
    ## Num $run_num
    my $run_num = shift;
    return path( $self->output_dir, $self->output_run_name . $run_num );
}

sub run_settings_dir   {
   my $self = shift;
   #Num $run_num
   my $run_num = shift;   
   my $settings_dir = path($self->run_dir($run_num), $self->run_settings_name );
   if( $settings_dir->exists){
      my $num_runs = scalar $settings_dir->children; 
      return path($settings_dir, $num_runs);
   }else{
      return path($settings_dir, 1);
   }
}

sub last_run_num {
    my $self=shift;
    #read in files in data directory
    #order by run number
    # - if none then run number is 1.
    my $run_num = max map { if( $_ =~ /run([0-9]+)/){$1}else{} } $self->output_dir->children;
    $run_num = 0 unless (defined $run_num);    
    return $run_num;   
}

sub new_run_settings_dir { 
   my $self = shift;
   #(Num $run_num){
   # this should generate a new settings 
   #dir taking into account reruns
   my $run_num = shift;   
   my $settings_dir = path($self->run_dir($run_num), $self->run_settings_name );
   
   if( $settings_dir->exists){
      my $num_runs = scalar $settings_dir->children + 1; 
      return path($settings_dir, $num_runs);
   }else{
      return path($settings_dir, 1);
   }  
}

sub datasource_from_run {
    my $self = shift;
    my $run_num = shift;
    my $settings_path = $self->run_settings_dir($run_num);   
    my $datasource_path = path($settings_path, $self->datasource_file->basename );
    return $datasource_path;
}




1;