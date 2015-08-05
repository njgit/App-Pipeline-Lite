use strict;
use warnings;
package App::Pipeline::Lite4;
use Moo;
use MooX::late;
use Ouch;
use Path::Tiny;
use YAML::Any;
use Types::Path::Tiny qw/Path AbsPath/;
extends 'App::Pipeline::Lite4::Base';
use App::Pipeline::Lite4::Util;
use App::Pipeline::Lite4::Parser; 
use App::Pipeline::Lite4::Resolver;
use App::Pipeline::Lite4::Grapher;
use File::Copy;
use Data::Dumper;
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

sub symlink {
    my $self      = shift;
    my $opt       = shift; # this is the options  with the id_field,symlinkdir if required
    #my $pipeline_file = shift;
    my $id_field = $opt->{id_field};
    
    my $STEP_AND_FNAME = $opt->{step_and_fname}; 
    
    my ($STEP,$FNAME);
    if( defined $STEP_AND_FNAME ){
      ($STEP,$FNAME) = split '#', $STEP_AND_FNAME;
    }
    
    my $parser = App::Pipeline::Lite4::Parser->new(
        pipeline_dir => $self->pipeline_dir,
     );
    
    $parser->preparse(  $self->pipeline_file, 
                        $self->pipeline_preparse_file ); 
    
    $parser->parse(  $self->pipeline_preparse_file, 
                     $self->pipeline_parse_file  );
    #warn "WORKING WITH DATASOURCE: " .    $self->datasource_file;
      
    my $resolver = App::Pipeline::Lite4::Resolver->new (                      
                       pipeline_dir         => $self->pipeline_dir,
                       #datasource_file     => $self->datasource_resolved_file,
                       #datasource_file      => defined( $opt->{datasource} ) ? $opt->{datasource} : $self->datasource_file,
                       datasource_file     => $self->datasource_file,
                       current_run_num      => defined( $self->run_num ) ? $self->run_num : undef,
                       step_filter_str      => defined( $self->step_filter_str) ? $self->step_filter_str : undef,
                       job_filter_str       => defined( $self->job_filter_str) ? $self->job_filter_str : undef,
                       #run_num_dep         => defined( $self->run_num_dep ) ? $self->run_num_dep : undef
                       );   
                       
    #warn Dumper $resolver->pipeline_datasource;                                          
    $resolver->resolve($self->pipeline_parse_file,$self->pipeline_resolved_file);
        
    my $datasource = $resolver->pipeline_datasource;
    
    # read resolved file YAML
    my $resolved_file_yaml = $self->pipeline_resolved_file->slurp;
    my $resolved_pipeline  = Load($resolved_file_yaml);
    my $output_run_dir = path( $self->output_dir, "run" . $self->run_num );
   
    foreach my $job_num (keys %$resolved_pipeline){
        my $job = $resolved_pipeline->{$job_num};         
        foreach my $step (keys %$job) {
            my $job_ids;   # A job_id is a label attached to each job based on the values in a column (specified by id_field) of the datasource

            if (defined ($STEP_AND_FNAME) ){
               next unless $step eq $STEP;
            }

            my $symlink_dir = path($resolver->symlink_dir, $step, $self->run_num);
            $symlink_dir->mkpath;
            my $condition = $job->{$step}->{condition};                   
            if(defined($condition) && $condition eq 'groupby'){
               my $condition_params = $job->{$step}->{condition_params};
               $job_ids = $self->_get_job_ids($id_field,$datasource,$condition_params);
               my $num_jobs = scalar @$job_ids;
               #warn "groupby step in symlink";
               next if $job_num >= $num_jobs ;
            }else{
               # get the job ids  
               $job_ids = $self->_get_job_ids($id_field,$datasource,undef);
            }
            
            if( defined $STEP_AND_FNAME ){
                my $file_path = path($output_run_dir,"job$job_num",$step,$FNAME);  
                if( $file_path->exists ) {
                    my $path_to_link = $file_path;
                    $self->_symlink_paths($job_num, $path_to_link,$job_ids,$symlink_dir,$opt->{name});
                }else{
                    warn "path $file_path does not exist - SYMLINK NOT MADE";
                }
                next;
            }

            my $outputfiles = $job->{$step}->{outputfiles};
            foreach my $outputfile ( @$outputfiles ){
               # warn "OUTPUTFILE: ", $outputfile,"\n";           
               my  $outputfile_path = path($output_run_dir,"job$job_num",$step,$outputfile);  
               # warn "LOOKING FOR $outputfile_path";          
               if( $outputfile_path->exists ) {
               #    warn "FOUND: ", $outputfile_path;
               #    my $symlink_path = path($symlink_dir,$job_ids->[$job_num]);
               #    warn "SYMLINK $outputfile_path $symlink_path";
                  my $path_to_link = $outputfile_path;
                  $self->_symlink_paths($job_num, $path_to_link,$job_ids,$symlink_dir,$opt->{name});
               }            
             }
         
            my $placeholders= $job->{$step}->{placeholders};
            foreach my $placeholder ( @$placeholders ){
                my $path_to_link;
                # warn "PLACEHOLDER: ", $placeholder,"\n";
                my ($file ) = $placeholder =~ /$step\.(.+)/;
                if( defined $file ){           
            
                   my  $file_path = path($output_run_dir,"job$job_num",$step,$file);    
                   #  warn "Looking for $file in $file_path";        
                   if( $file_path->exists ) {
                       #warn "FOUND: ", $file_path;     
                       my $path_to_link = $file_path; 
                       $self->_symlink_paths($job_num,$path_to_link,$job_ids,$symlink_dir,$opt->{name});        
                   }
                }else{
                      #warn "no file in $placeholder";
                }
         }
       }
    }   
}
 
sub _symlink_paths {
    my $self = shift;
    my $job_num = shift;
    my $path_to_link =shift;
    my $job_ids =shift;
    my $symlink_dir = shift;
    my $name = shift;
    
    if(defined $path_to_link){
             my $id =$job_ids->[$job_num];
             my $new_basename = "$id-".$path_to_link->basename;
             if( defined( $name )){
                $new_basename = "$id$name" ;                                
              }     
             my $symlink_path = path($symlink_dir,$new_basename);        
             #my $symlink_path = path($symlink_dir,$job_ids->[$job_num],$file_path);
             print STDERR " SYMLINK $path_to_link $symlink_path\n";    
             CORE::symlink $path_to_link, $symlink_path;       
         }  
} 
 
sub _get_job_ids {
    my $self = shift;
    my $id_field = shift;  
    my $datasource = shift;
    my $groupby_fields = shift;
    
    my @job_ids ;
    if(defined $groupby_fields){
        my $groupby_field = $groupby_fields->[0];  # only one group by supported at the moment
        if( $groupby_field eq $id_field){      
            $datasource = $datasource->group([$groupby_field],[$id_field],[sub { $_[0] } ],["$id_field-group"] );
        }else{
            $datasource = $datasource->group([$groupby_field],[$id_field],[sub { join("-",@_) } ],["$id_field-group"] );
        }        
        #$self->logger->debug("Symlink - grouped datasource looks like " . $datasource->tsv );
        $id_field = "$id_field-group";
    }
   
    if( ! defined( $id_field) ){
           warn "No ID field defined. Prepending job numbers " ;
           @job_ids = map {"job$_"} (0 .. $datasource->nofRow -1 );
    }elsif( $datasource->hasCol($id_field) ){
           @job_ids = $datasource->col($id_field);
    }else{
           warn "No matching ID field in datasource. Prepending job numbers";
           @job_ids = map {"job$_"} (0 .. $datasource->nofRow -1 );
    }    
    return \@job_ids;  
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
    #warn "WORKING WITH DATASOURCE: " .    $self->datasource_file;
      
    my $resolver = App::Pipeline::Lite4::Resolver->new (                      
                       pipeline_dir         => $self->pipeline_dir,
                       #datasource_file      => $self->datasource_resolved_file,
                       datasource_file      => $self->datasource_file,
                       current_run_num      => defined( $self->run_num ) ? $self->run_num : undef,
                       step_filter_str      => defined( $self->step_filter_str) ? $self->step_filter_str : undef,
                       job_filter_str       => defined( $self->job_filter_str) ? $self->job_filter_str : undef,
                       #run_num_dep          => defined( $self->run_num_dep ) ? $self->run_num_dep : undef
                       );   
                       
   #warn Dumper $resolver->pipeline_datasource;                                       
   
   $resolver->resolve($self->pipeline_parse_file,$self->pipeline_resolved_file); 
   
   
    my $grapher = App::Pipeline::Lite4::Grapher->new ( 
                       pipeline_dir    => $self->pipeline_dir,
                       datasource_file => $self->datasource_file,
                       );     
                                         
    $grapher->add_dependents(  $self->pipeline_resolved_file, 
                               $self->pipeline_graph_file );                
     
    # copy stuff over to settings directory
    my $run_num = $resolver->current_run_num;
    $self->copy_pipeline_files_to_run_settings_dir($run_num); 
     
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
   
}

sub external_dispatch {
   # TYPE  Path::Tiny :$dispatcher_exe )  {
    my $self = shift;
    my $dispatcher_opt = shift;
    my ($dispatcher_exe, $opts) = split / /, $dispatcher_opt;
    
    my $pipeline_graph_file = $self->pipeline_graph_file->absolute;
    
  # ouch 'App_Pipeline_Lite4_Error', "Dispatcher does not exist at $dispatcher_exe" 
  #  unless $dispatcher_exe->exists;
    
     my $dispatcher_path_str = $dispatcher_exe;     
    ouch  'App_Pipeline_Lite4_Error', "Dispatcher app is not executable" 
      unless ( -x $dispatcher_path_str);  
      
    my $dispatcher_cmd =  qq{ dispatcher_opt->absolute->stringify  $pipeline_graph_file };
    system( $dispatcher_cmd );    
}


sub copy_pipeline_files_to_run_settings_dir  {
   
   my $self = shift;
   my $run_num = shift;
   $self->new_run_settings_dir($run_num)->mkpath unless $self->new_run_settings_dir($run_num)->exists;  
   
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
