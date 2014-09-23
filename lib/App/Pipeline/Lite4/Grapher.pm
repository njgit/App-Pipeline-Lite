use strict;
use warnings;
package App::Pipeline::Lite4::Grapher;
use Moo;
use MooX::late;
use Ouch;
use Path::Tiny;
use YAML::Any;
#use List::AllUtils qw(min any); can't use as get kick ups about requiring versions > 1.32
use List::Util qw(min reduce);
use Data::Compare;
use Data::Dumper;
use App::Pipeline::Lite4::Util;
extends 'App::Pipeline::Lite4::Base';
has pipeline_step_struct_with_dependents => ( isa => 'HashRef', is => 'rw' );

sub add_dependents {
   my $self=shift;
   # Path::Tiny :$yaml_infile,
   my $yaml_infile = shift;  
   # Path::Tiny :$yaml_outfile
   my $yaml_outfile = shift;
   $self->pipeline_resolved_file($yaml_infile);
   $self->_add_dependents;
   $yaml_outfile->spew( Dump( $self->pipeline_step_struct_with_dependents ) );
}

#method _add_dependents {    
sub _add_dependents {
    my $self = shift;
    my $resolved_file_yaml = $self->pipeline_resolved_file->slurp;
    my $resolved_pipeline = Load($resolved_file_yaml); 
    
    my $lowest_job_num = min keys $resolved_pipeline;
    my $num_of_jobs    = scalar keys $resolved_pipeline;
    
   # my $valid_steps = $self->valid_steps( $resolved_pipeline);
    my $valid_steps = $self->valid_steps_hash( $resolved_pipeline);
    
    foreach my $job_num (keys %$resolved_pipeline){
        my $job = $resolved_pipeline->{$job_num};
        foreach my $step (keys %$job) {
           $job->{$step}->{dependents} = [];
           if( defined($job->{$step}->{placeholders})) {
              $self->_add_dependents_for_step_via_placeholder( 
                        $job->{$step}, #step
                        $step, #step_name 
                        $job_num,
                        $lowest_job_num,  
                        $num_of_jobs, 
                        $valid_steps 
                        );
           }
           
           if( defined( $job->{$step}->{after}) ) {
               $self->_add_dependents_for_step_via_after_condition( 
                        $job->{$step}, #step
                        $step,   #sep_name
                        $job_num, 
                        $lowest_job_num, 
                        $num_of_jobs, 
                        $valid_steps );  
           }           
        }
    }
    $self->pipeline_step_struct_with_dependents($resolved_pipeline);
}

sub _add_dependents_for_step_via_placeholder {
# TYPE (  HashRef :$step, Str :$step_name, Num :$job_num, Num :$lowest_job_num, 
# TYPE Num :$num_of_jobs, ArrayRef :$valid_steps ) {
     my ($self,$step,$step_name,$job_num, $lowest_job_num, 
         $num_of_jobs,$valid_steps_hash  ) = @_;
     
     $self->logger->debug( "Valid Steps: " . Dumper $valid_steps_hash );
     my $rgx1 = qr{^([\w\-]+)\.{0,1}};
     my $rgx2 = qr{^jobs\.([\w\-]+)\.{0,1}};      
     my $rgx3 = qr{groupbyebyebye}; # should not match anything
     if( defined( $step->{condition} ) ){         
       if(  $step->{condition} eq 'groupby'){
         my $params = $step->{condition_params};     
         my $params_str = join '\.', @$params;
         my $rgx3_str = '^groupby\.' . $params_str . '\.' . '([\w\-]+)\.{0,1}';
         $rgx3 = qr{$rgx3_str};
       }
     } 
     #warn "REGEX3 $rgx3";     
     my $placeholders = $step->{placeholders};
     my $dependents   = $step->{dependents};
     
     my @valid_steps = keys %$valid_steps_hash;
     foreach my $placeholder (@$placeholders){                                    
         my ($placeholder_step_name) = $placeholder =~ $rgx2;#/^(\w+)\.{0,1}/; # =~ /step([0-9]+)/;
         ($placeholder_step_name) = $placeholder =~ $rgx3 unless defined($placeholder_step_name);
         ($placeholder_step_name) = $placeholder =~ $rgx1 unless defined($placeholder_step_name);
          
         # warn "GOT STEP NAME: $placeholder_step_name from $placeholder";
         $self->logger->debug("step $step_name: placeholder step name - $placeholder_step_name (from $placeholder)");  
         next unless defined($placeholder_step_name);
         
         ### I want 'any' unfortunately any isn't in recent version of List::Util and List::MoreUtils is XS and not core
         my $code = sub { my $k = shift; return 1 if( $placeholder_step_name eq $k ); return 0;   };
         my $next = reduce { $a || $code->(local $_ = $b)  } 0,  @valid_steps;
         next unless $next;
         
         # DO THIS WHEN List::Util qw(any) works for most Perls  
         #next unless any { $placeholder_step_name eq $_ } @$valid_steps; # if we have filtered steps this is important, and also takes care of the 0 datasource step
         ########################################################
         
                
             my ($existing_dependents, $this_step_name) = (0,0);
             
             ## Actually want List::Util qw(any)
             my $codeA = sub { my $k = shift; return 1 if( "$job_num.$placeholder_step_name"  eq $k ); return 0;   };
             $existing_dependents = reduce { $a || $codeA->(local $_ = $b)  } 0,  @$dependents;
             
             # DO THIS WHEN List::Util qw(any) works for most Perls  
             #$existing_dependents =  any { $_ eq "$job_num.$placeholder_step_name"  }  @$dependents;
             ##############################################################################
             $this_step_name = 1 if( $placeholder_step_name eq $step_name);                                   
             if ( defined $step->{condition} ) {
                 # only defined condition is 'once' so far
                 # the 'any' code above will skip adding the same dependent jobs if a placeholder with the same step name occurs multiple times. 
                 # it works because it sets $existing_dependents true if any of the job numbers is present                
                 #---
                 if( $step->{condition} eq 'once'){ 
                     # now a once condition referencing another step with a once condition only needs to put down the minimal job number
                     # remember we are looking at the placeholder and trying to determine dependencies,
                     # the valid steps hash, tells us what condition the step of that placeholder is, so we can 
                     # adjust for once or groupby steps
                     if( defined $valid_steps_hash->{$placeholder_step_name}->{condition} ){             
                         if( $valid_steps_hash->{$placeholder_step_name}->{condition} eq 'once' ){
                           push(@$dependents, "$lowest_job_num.$placeholder_step_name") unless ( $this_step_name or $existing_dependents) ; 
                         }
                     }else {
                         for my $i ( $lowest_job_num .. ( $num_of_jobs -1 )){
                            push(@$dependents, "$i.$placeholder_step_name") unless ( $this_step_name or $existing_dependents) ;                                               
                         }
                  
                     }
                   }
                   if ( $step->{condition} eq 'groupby'  ){
                       
                       #we take the job number and get the group we need
                       my $util = App::Pipeline::Lite4::Util->new;
                       my $params = $step->{condition_params};
                       #warn "PARAMS: ", Dumper $params;
                       my $groupby_hash = $util->datasource_groupby2( $self->pipeline_datasource, @$params );
                       my $groupby_ids  = $util->datasource_groupby2_order($self->pipeline_datasource, @$params);
                       #my @groupby_ids = sort keys %$groupby_hash;
                       #warn "GRAPHER JOBNUM: $job_num";
                       #warn "GRAPHER GROUPID: @groupby_ids";
                       #warn "gRAPHER CMD", $step->{cmd};
                       #warn "STEP",  Dumper $step;
                       my $group_id = $groupby_ids->[$job_num]; 
                       #warn "GRAPHER GROUPID: $group_id";
                       my $job_ids = $groupby_hash->{$group_id};
                       
                       
                       # if we are referring to a step that is a groupby step, then we only need to 
                       # put int dependencies that refer to the jobs generated by that step - i.e. only up to job 4 rather
                       # than job 10 for example, as it won't exist 
                       
                       if( defined $valid_steps_hash->{$placeholder_step_name}->{condition} ){             
                         if( $valid_steps_hash->{$placeholder_step_name}->{condition} eq 'groupby' ){
                             # different conditions will have different numbers, 
                             # we can only refer to a groupby with the same condition  
                             # and then we only put in the job number, 
                             my $placeholder_step_params = $valid_steps_hash->{$placeholder_step_name}->{condition_params};
                             #my $comp = Array::Compare->new; 
                             if( ! Compare( $placeholder_step_params, $params  ) ){
                                ouch 'App_Pipeline4_Error', "One groupby statement depends on another groupby statement with a different groupby field(s)";
                             }else{
                                
                                push(@$dependents, "$job_num.$placeholder_step_name") 
                                   unless ( $this_step_name or $existing_dependents or ($job_num >= scalar(@$groupby_ids)) ); 
                             } 
                         }
                         #do something for once here
                        }else{
                       
                           foreach my $job_id (@$job_ids){  
                              push( @$dependents, "$job_id.$placeholder_step_name" ) unless ( $this_step_name or $existing_dependents) ;
                           }
                       }
                   } 
                 
             }else{                 
                 #$existing_dependents =  any { $_ eq "$job_num.$placeholder_step_name"  }  @$dependents;
                 #$this_step_name = 1 if( $placeholder_step_name eq $step_name);  
                 if( defined ( $valid_steps_hash->{$placeholder_step_name}->{condition} ) ){                     
                     if( $valid_steps_hash->{$placeholder_step_name}->{condition} eq 'once'){
                          push( @$dependents, "$lowest_job_num.$placeholder_step_name")
                              unless ($this_step_name or $existing_dependents) ; 
                     }
                     
                  }else{
                    push( @$dependents, "$job_num.$placeholder_step_name")
                      unless ($this_step_name or $existing_dependents) ;
                 }
             }       
         #}         
     }
}
=cut To implement
sub _add_dependents_for_step_via_after_condition {
    #TYPE: HashRef :$step, Str :$step_name, Num :$job_num, 
    #TYPE: Num :$lowest_job_num, Num :$num_of_jobs, ArrayRef :$valid_steps )
      my ($self,$step,$step_name,$job_num, $lowest_job_num, 
         $num_of_jobs,$valid_steps_hash  ) = @_;
      foreach my $after_step_name ($step->{after}->flatten){
        # if($after_step_num > $step) {
           # ouch 'steperror', "Need to ensure that a step does not define steps to run after that are future steps"; 
        # } 
        
       # if ( $after_step_num < $step_num ) { 
            my $dependents = $step->{dependents};  
             $self->logger->debug("step $step_name: placeholder step num - $after_step_name");                         
             if ( defined $step->{condition} ) { # only 'once' is the only thing that can occur from the condition key                
                 for my $i ( $lowest_job_num .. ( $num_of_jobs -1 )){
                     push( @$dependents, "$i.$after_step_name");                                               
                 }
             }else{
                 ouch 'App_Pipeline4_Error', "The after condition of step $step_name refers to its own step"
                   if( $after_step_name eq $step_name );
                
                 push(@$dependents, "$job_num.$after_step_name")
                   unless any { $_ eq "$job_num.$after_step_name"  }  @$dependents ;
             }       
       #  }                    
                   
    }
}
=cut

####DEPRECATED## REMOVE
sub valid_steps {
  #TYPE: ( HashRef :$resolved_pipeline ) {
  my $self = shift;    
  my $resolved_pipeline = shift;  
  # run through the first job.  
  my ($a_job);
  my @jobs = keys %$resolved_pipeline;
  my ($min_job_num) = sort {$a <=> $b} @jobs;
  $a_job =  $resolved_pipeline->{$min_job_num}; 
  my @step_names =  keys %$a_job;
  warn "@step_names";
  return \@step_names;    
} 
############


sub valid_steps_hash {
  #TYPE: ( HashRef :$resolved_pipeline ) {
  my $self = shift;    
  my $resolved_pipeline = shift;  
  # run through the first job.  
  my ($a_job);
  my @jobs = keys %$resolved_pipeline;
  my ($min_job_num) = sort {$a <=> $b} @jobs;
  $a_job =  $resolved_pipeline->{$min_job_num}; 
  my @step_names =  keys %$a_job;
  my %valid_step_hash;
  foreach my $step (keys %$a_job){
     $valid_step_hash{$step}->{condition} = $a_job->{$step}->{condition};
     $valid_step_hash{$step}->{condition_params} = $a_job->{$step}->{condition_params};   
  }
  
  return \%valid_step_hash;
} 

1;
