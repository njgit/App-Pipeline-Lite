use strict;
use warnings;
package App::Pipeline::Lite4;
use Moo;
use MooX::late;
use Ouch;
use Path::Tiny;
use Types::Path::Tiny qw/Path AbsPath/;
extends 'App::Pipeline::Lite4::Base';
use App::Pipeline::Lite4::Util;
use App::Pipeline::Lite4::Parser; 
use App::Pipeline::Lite4::Resolver;
use App::Pipeline::Lite4::Grapher;
use File::Copy;
has smoke_test => ( isa => 'Bool', is => 'rw', default => sub {0} ); 
has external_dispatcher => ( isa => 'Path::Tiny|Undef', is => 'rw', 
                              lazy_build => 1 );

sub _build_external_dispatcher {
    my $self = shift;  
      
    my $dispatcher = $self->config->{_}->{dispatcher}; #check local config 
    
    # if does not exist, check system config    
    $dispatcher = $self->system_config->{_}->{dispatcher} 
                               unless defined( $dispatcher);
    
    defined($dispatcher) ?  path($dispatcher) : undef;    
}

sub util {
    my $self = shift;
    # give back object with utilities
    return App::Pipeline::Lite4::Util->new(  pipeline_dir => $self->pipeline_dir);
}

sub run_pipeline {
    my $self = shift;   
    my $pipeline_file = shift; 

   # RESOLVE DATASOURCE HERE

    my $parser = App::Pipeline::Lite4::Parser->new(
        pipeline_dir => $self->pipeline_dir,
     );
    
    $parser->preparse(  $self->pipeline_file, 
                        $self->pipeline_preparse_file ); 
    
    $parser->parse(  $self->pipeline_preparse_file, 
                     $self->pipeline_parse_file  );
        
    my $resolver = App::Pipeline::Lite4::Resolver->new (                      
                       pipeline_dir         => $self->pipeline_dir,
                       #datasource_file      => $self->datasource_resolved_file,
                       datasource_file      => $self->datasource_file,
                       current_run_num      => defined( $self->run_num ) ? $self->run_num : undef,
                       step_filter_str      => defined( $self->step_filter_str) ? $self->step_filter_str : undef,
                       job_filter_str       => defined( $self->job_filter_str) ? $self->job_filter_str : undef,
                       #run_num_dep          => defined( $self->run_num_dep ) ? $self->run_num_dep : undef
                       );                      
   $resolver->resolve($self->pipeline_parse_file,$self->pipeline_resolved_file); 
   
   
    my $grapher = App::Pipeline::Lite4::Grapher->new ( 
                       pipeline_dir => $self->pipeline_dir,
                       );     
                                         
    $grapher->add_dependents(  $self->pipeline_resolved_file, 
                               $self->pipeline_graph_file );                

    if ( ! $self->smoke_test ) { 
      if( defined( $self->external_dispatcher ) ) {       
         $self->external_dispatch( $self->external_dispatcher );            
      } else {
          print "\n*** dispatcher not defined - see config file ***\n";
          # warn using local dispatch option
          #print "\n***\n\nUsing built in dispatcher\n\n***\n";
          #my $dispatcher = App::Pipeline::Lite4::Dispatcher->new( 
          #             pipeline_graph_file => $self->pipeline_graph_file,
          #             logfile => $self->logfile );                                      
          #$dispatcher->dispatch;    
     }
   }else{      
     $self->logger->debug("Smoke Test!");    
   }
   
   # copy stuff over to settings directory
   my $run_num = $resolver->current_run_num;
   $self->copy_pipeline_files_to_run_settings_dir($run_num);
}

sub external_dispatch {
   # TYPE  Path::Tiny :$dispatcher_exe )  {
    my $self=shift;
    my $dispatcher_exe=shift;
    
    my $pipeline_dir = $self->pipeline_dir->absolute->stringify;
    ouch 'App_Pipeline_Lite4_Error', "Dispatcher does not exist at $dispatcher_exe" 
     unless $dispatcher_exe->exists;
    
     my $dispatcher_path_str = $dispatcher_exe->absolute->stringify;     
    ouch  'App_Pipeline_Lite4_Error', "Dispatcher app is not executable" 
      unless ( -x $dispatcher_path_str);  
      
    my $dispatcher_cmd =  qq{ $dispatcher_path_str  $pipeline_dir };
    system( $dispatcher_cmd );    
}


sub copy_pipeline_files_to_run_settings_dir  {
   
   my $self = shift;
   my $run_num = shift;
   $self->new_run_settings_dir($run_num)->mkpath unless $self->run_settings_dir($run_num)->exists;  
   
   copy( $self->pipeline_file->stringify , $self->run_settings_dir($run_num)->stringify )
     or ouch 'App_Pipeline_Lite4_Error', "Couldn't copy pipeline file to run settings directory";
   
   copy( $self->pipeline_graph_file->stringify , $self->run_settings_dir($run_num)->stringify )
     or ouch 'App_Pipeline_Lite4_Error', "Couldn't copy graph file to run settings directory";
    
   copy( $self->datasource_file->stringify , $self->run_settings_dir($run_num)->stringify )
     or ouch 'App_Pipeline_Lite4_Error', "Couldn't copy datasource file to run settings directory"; 
     
   #make a standardised version to the pipeline name 
   copy( $self->datasource_file->stringify , path( $self->run_settings_dir($run_num), $self->pipeline_name . ".datasource" )->stringify )
     or ouch 'App_Pipeline_Lite4_Error', "Couldn't copy datasource file to run settings directory"; 
    
   #copy( $self->datasource_resolved_file->stringify , $self->run_settings_dir($run_num)->stringify )
   #  or ouch 'App_Pipeline_Lite4_Error', "Couldn't copy resolved datasource file to run settings directory"; 
     
   if( $self->software_ini_file->exists){ 
       copy( $self->software_ini_file->stringify , $self->run_settings_dir($run_num)->stringify )
         or ouch 'App_Pipeline_Lite4_Error', "Couldn't copy software ini file to run settings directory";
   }
}



1;
