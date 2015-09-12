use strict;
use warnings;
package App::Pipeline::Lite4::Resolver ;
use Moo;
use MooX::late;
use Ouch;
use Path::Tiny;
use Types::Path::Tiny qw/Path AbsPath/;
use YAML::Any;
use List::Util qw(max reduce);
use Data::Table;
use Data::Dumper;
use App::Pipeline::Lite4::Template::TinyMod;
use App::Pipeline::Lite4::Util;
use Storable qw(dclone);
extends 'App::Pipeline::Lite4::Base';

has placeholder_hash     => ( isa =>'HashRef', is => 'rw', default => sub {return {}});
has current_run_num => ( isa => 'Num|Undef', is => 'rw');
has current_run_dir => (isa => Path, is =>'rw', lazy_build => 1);
has pipeline_step_struct => ( isa => 'HashRef' , is => 'rw', lazy_build => 1 );
has pipeline_step_struct_resolved => ( isa => 'HashRef' , is => 'rw', default => sub {{}}  );
has run_num_dep  => ( isa => 'Num|Undef', is => 'rw');
has tot_jobs => ( isa => 'Num', is => 'ro', lazy_build => 1);
has job_filter => ( isa  => 'ArrayRef|Undef', is =>'rw', lazy_build => 1 );
has step_filter => ( isa => 'ArrayRef|Undef' , is => 'rw', lazy_build =>1 );

sub _build_pipeline_step_struct {
     my $self = shift;
     my $yaml = $self->pipeline_parse_file->slurp;
     return Load($yaml);
}

sub _build_current_run_dir {
    my $self = shift;
    return  path( $self->output_dir, $self->output_run_name . ($self->current_run_num) );
}

sub _build_tot_jobs {
    my $self = shift;
    return $self->pipeline_datasource->lastRow + 1;
}

sub _build_job_filter  {
    my $self= shift;

    #check the jobs don't exceed the datasource
    my $ds_rows = $self->pipeline_datasource->nofRow;

    if( defined $self->job_filter_str ) {
        #my @jobs_to_keep = $self->job_filter_str->split('\s+');
        #return \@jobs_to_keep;
        my $jobs = $self->_parse_job_filter_str($self->job_filter_str);
        my $max_job = max( @$jobs );
        #$self->logger->debug("Check max job filter row with number of datasource rows: ($ds_rows) ");
        $self->logger->debug("Check max of jobs in job filter: ( @$jobs max = $max_job)
                               with num of datasource rows: ($ds_rows) ");
        #jobs start from 0
        ouch 'App_Pipeline_Lite4_ERROR', "max job in filter exceeds datasource row." if $max_job >= $ds_rows ;

        return $jobs;
    } else {
        return undef;
    }
}

sub _parse_job_filter_str {
    my $self = shift;
    my $job_filter_str = shift;
    my @job_filters = split ',', $job_filter_str;
    my @jobs;
    foreach my $job_filter (@job_filters){
        if($job_filter =~ '-'){
           my @pair = split '-', $job_filter;
           push @jobs, $pair[0] .. $pair[1];
        }else{
           push @jobs, $job_filter;
        }

    }
    return [ App::Pipeline::Lite4::Util::uniq( @jobs ) ];
}


sub _build_step_filter {
    my $self = shift;
    if( defined $self->step_filter_str ) {
        #my ($start_step, $end_step) = $self->step_filter_str =~ /([0-9]+)\-([0-9]+)/;
        my @steps;
        #if(defined($start_step) and defined($end_step)){
        #   @steps = $start_step .. $end_step;
        #   return \@steps;
        #} else {
           @steps = split '\s+', $self->step_filter_str;
           return \@steps;
        #}
    } else {
        return undef;
    }
}

#does this only need to be done on a per job basis.
sub _step_filter_on_resolved_step_struct  {
        my $self = shift;
        my $steps = $self->step_filter;
        #warn "@$steps";
        my $resolved_step_struct = $self->pipeline_step_struct_resolved;
        $self->logger->debug( "Steps to keep: @$steps\n");
        foreach my $step_struct (values %$resolved_step_struct) {
            foreach my $step_name ( keys %$step_struct) {
               $self->logger->debug( "Checking $step_name against filter\n" );

               #### WE WANT ANY####
               my $code = sub { my $k = shift; return 1 if( $step_name eq $k ); return 0;   };
               my $dont_delete = reduce { $a || $code->(local $_ = $b)  } 0,  @$steps;

               #delete $step_struct->{$step_name} unless any{ ($step_name eq $_) } any{ ($step_name eq $_) } @$steps;
               #######

               delete $step_struct->{$step_name} unless $dont_delete; #any{ ($step_name eq $_) } @$steps;
            }
        }
        #the run number must be set to the last run. otherwise we could end up with dependency issues.
        #this might not be good enough, e.g. we may have run a smoke_test - this creates output directories
        #my $last_run_num = App::Pipeline::Lite1::Resolver->new( output_dir => $self->output_dir)->_last_run_number;
        #$self->run_num($last_run_num) unless defined($self->run_num); #the user has already assigned a run number we use this
        #$self->logger->debug("Set run number to " . $self->run_num);
}

sub _job_filter_on_resolved_step_struct   {
     my $self=shift;
     my $jobs_to_keep= $self->job_filter;

     my $resolved_step_struct = $self->pipeline_step_struct_resolved;
     $self->logger->debug( "Jobs to keep: @$jobs_to_keep\n");

     $self->logger->debug( "RESOLVED STEP STRUCT BEFORE FILTER: " . Dumper($resolved_step_struct)  );


     foreach my $job_num (keys %$resolved_step_struct) {

          #### WE WANT ANY####
               my $code = sub { my $k = shift; return 1 if( $job_num eq $k ); return 0;   };
               my $dont_delete = reduce { $a || $code->(local $_ = $b)  } 0,  @$jobs_to_keep;
          #delete $resolved_step_struct->{$job_num} unless any { ($job_num == $_) } @$jobs_to_keep;
          #######

         delete $resolved_step_struct->{$job_num} unless $dont_delete;
     }

     $self->logger->debug( "RESOLVED STEP STRUCT AFTER FILTER: " . Dumper($resolved_step_struct)  );
}

sub resolve {
   my $self = shift;
   # TYPE: ( Path::Class::File :$yaml_infile,  Path::Class::File :$yaml_outfile )
   my $yaml_infile  = shift;
   my $yaml_outfile = shift;
   $self->pipeline_parse_file($yaml_infile); #sets the path to yaml file produced by parser step
   $self->_resolve;
   $yaml_outfile->spew( Dump( $self->pipeline_step_struct_resolved ) );
}


=method _resolve
    The resolver takes something like this: 
    {'count-all' => {
                    'condition' => 'once',
                    'placeholders' => [
                                        'count-all',
                                        'jobs.datasource.filename',
                                        'count-all.sum',
                                        'count-all.err'
                                      ],
                    'cmd' => 'cd [% count-all %]; wc -l [% jobs.datasource.filename %] > [% count-all.sum %] 2>[% count-all.err %]'
                  },
    }
    
    and converts it to something like this(showing just job3 (starting from job0):
    
    {'3' => {    
              
              'count-all' => {
                                    'condition' => 'once',
                                    'placeholders' => [
                                                        'count-all',
                                                        'jobs.datasource.filename',
                                                        'count-all.sum',
                                                        'count-all.err'
                                                      ],
                                    'cmd' => 'cd /home/user/Desktop/plite-test-once-condition/test-pipeline1/output/run3/job3/count-all; wc -l /home/user/Desktop/plite-test-once-conditio
n/data/sample4 /home/user/Desktop/plite-test-once-condition/data/sample5 /home/user/Desktop/plite-test-once-condition/data/sample6 /home/user/Desktop/plite-test-once-condition/data/sample
7 > /home/user/Desktop/plite-test-once-condition/test-pipeline1/output/run3/job3/count-all/sum 2>/home/user/Desktop/plite-test-once-condition/test-pipeline1/output/run3/job3/count-all/er
r'
                                  },
                   }
      }


=cut

sub _resolve {
    my $self = shift;
    #$self->clear_pipeline_step_struct_resolved;
    $self->current_run_num( $self->_last_run_number + 1 ) unless defined( $self->current_run_num);

    foreach my $row ( 0 .. $self->pipeline_datasource->lastRow ) {
         $self->logger->log("debug", "=== Job $row  ===");
         $self->_add_data_source_to_placeholder_hash( $row);
          #add input file directory to placeholder hash
         $self->_add_input_files_to_placeholder_hash;

         # add globals to placeholder hash
         ##$self->_add_dir_to_placeholder_hash ( dir_name => 'global', dir_path => dir( $self->output_dir , 'run' . ($self->current_run_num) ));
         # add data dir to placeholder hash
         ##$self->_add_dir_to_placeholder_hash ( dir_name => 'data', dir_path => dir( $self->output_dir->parent ) );

         # add in the output files expected for each step to the placeholder hash
         
         #$self->_add_steps_in_step_struct_to_placeholder_hash($row);
         $self->_add_steps_in_step_struct_to_placeholder_hash2($row);
         $self->_create_directory_structure_from_placeholder_hash;

         # add software to placeholder hash - MUST GO AFTER CREATE DIRECTORY
         # OTHERWISE DIRECTORIES WILL BE MADE FOR SOFTWARE
         $self->_add_software_to_placeholder_hash;

         # add in the output files expected for each step to the placeholder hash
         $self->_add_expected_output_files_to_placeholder_hash( $row);
         $self->_add_expected_output_files_to_jobs_in_placeholder_hash;
         #warn Dumper $self->placeholder_hash;

         # validate placeholders against placeholder hash
         $self->_validate_placeholder_hash_with_placeholders;
         # interpolate the cmds in each step and add to new resolved_step_struct
         $self->_interpolate_cmd_in_step_struct_to_resolved_step_struct( $row);
         $self->_step_filter_on_resolved_step_struct if defined $self->step_filter_str;
         $self->_job_filter_on_resolved_step_struct if defined $self->job_filter_str;
         $self->_once_condition_filter_on_resolved_step_struct;
         $self->_groupby_condition_filter_on_resolved_step_struct;
         #warn Dumper $self->pipeline_step_struct_resolved;
         $self->placeholder_hash({});
    }
    #$self->logger->log( "info", "Final Resolved Step Struct: \n" . Dumper $self->pipeline_step_struct_resolved );
}


=method _add_data_source_to_placeholder_hash
   Reads the data source as specified in $self->pipeline_datasource and
   parses a specified row of the datasource to the placeholder_hash
=cut
sub _add_data_source_to_placeholder_hash{
      #TYPE:  Num :$datasource_row
      my $self = shift;
      my $datasource_row = shift;
      my $t = $self->pipeline_datasource;
      my @header = $t->header;
      for my $i (0 .. $t->lastCol ) {
         #print $header[$i], " ", $t->col($i), "\n";    
         my @datasource_rows = $t->col($i);
         $self->logger->log( "debug", "Datasource col $i : ".$header[$i] . " =>  $datasource_rows[$datasource_row]");
         #adds in the datasource reference here, so that we can deal specially with datasource stuff later in create_directory_structure
         $self->_placeholder_hash_add_item( "datasource." . $header[$i],  $datasource_rows[$datasource_row]  );

    }
}


sub _add_software_to_placeholder_hash {
    my $self = shift;
    return unless defined $self->software_dir;
    my $dir = $self->software_dir;
    return unless $dir->exists;
    my @software = $dir->children;

    #add to placeholder;
    for my $i (0 .. $#software) {
       $self->_placeholder_hash_add_item( "software.".$software[$i]->basename, $software[$i]->stringify )
        unless $software[$i]->stringify eq $self->software_ini_file->stringify;
    }

    # we then need to add the software in in the software.ini file
    return unless defined $self->software_ini;
    return unless $self->software_ini_file->exists;
    foreach my $software_name ( keys %{ $self->software_ini->{_} }  ) {
        $self->_placeholder_hash_add_item(  "software.$software_name", $self->software_ini->{_}->{$software_name} );
    }
}


sub _add_input_files_to_placeholder_hash {
   my $self = shift;
   # read folder called input add to the placeholder hash
   # can add folders to input directory and it will pick the names
   return unless defined $self->input_dir;
   my $dir = $self->input_dir;
   return unless $dir->stat;

   ouch 'App_Pipeline_Lite4_ERROR', "The input directory $dir does not exist" unless $dir->stat;

   my @files;

   my $iter = $dir->iterator( { recurse => 1 } );
   while( my $path = $iter->() ){
        next unless( $path->is_file || $path->is_dir);
        push( @files, $path);
   }
    #add to placeholder;
    for my $i (0 .. $#files) {
       $self->_placeholder_hash_add_item( "input.".$files[$i]->basename,
                                           $files[$i]->stringify );
    }
}

# placeholder hash is where we have {step0}{file1} = value
# currently we leave it for the groupby case, so that we just have a long key that still matched fine
# probably we should have the step and its field names as one key
# {groupby}{cmp.hmr}{file.name} = /outputdir/job../hmr/file.name
sub _placeholder_hash_add_item{
   #TYPE: ( Str :$keystr, Str :$value)
   my $self   = shift;
   my $keystr = shift;
   my $value  = shift;
   my @keystr = split('\.', $keystr);
   if( $keystr[0] eq 'jobs'){
	  @keystr = ( $keystr[0], $keystr[1], join('.', @keystr[2 .. $#keystr]  ) );
	}else {
      @keystr = ( $keystr[0], join('.', @keystr[1 .. $#keystr]  ) );
	}
   if (@keystr == 2){
    $self->placeholder_hash->{ $keystr[0] }{ $keystr[1] } = $value ;
    $self->logger->log("debug", " _placeholder_hash_add_item:  Adding @keystr and $value. Value from hash: " . $self->placeholder_hash->{ $keystr[0] }{ $keystr[1] });

   }
    if (@keystr == 3){
       $self->placeholder_hash->{ $keystr[0] }{ $keystr[1] }{ $keystr[2] } = $value;
   }
}


=method 
This function gives the grouping index when there is a job filter present. To see why we need to do this
consider the following example of how where we want our groupby jobs to end up - i.e. for 3 groups we want
them to have their output in the first 3 jobs. In the following example, we have filtered all of group A
jobs. So there will be nothing in job0.

The group order is set by a alphanumeric sort of the group names.

Grp  jobid  jobs-executed   jobs-in-output
  A  0                            ( nothing in job0)
  B  1 -->   x             1 ---> (group 2 in job1 by sorting order)
  A  2                     5 ---> (group 3 in job2 by sorting order)
  A  3  
  B  4 -->   x
  C  5 -->   x 

So we have to construct job_ids to group numbers:

  [ 0 --> 1, 1 --> 2, 2 --> 1, 3 --> 1, 4 --> 2, 5 --> 3 ]

Then we have to do filter out non executed jobs (using the job filter that lists all the jobs to be executed)
  
   [  1 --> 2, 4 --> 2, 5 --> 3 ]
 
Finally we have to uniq the values and collapse them:

  [  1 --> 2, 4 --> 3, 5 --> 0]

The 5 --> 0 is the third run that is executed , and it is given a default group_idx of zero, because we don't actually
care about how this is executed and it should be pruned in the groupby pruning step. 
Now we have a hash that gives back the right group_idx for a particular run.
Of course we require the correct behaviour in the groupby pruning to see this work properly.   
=cut 

sub get_grouping_indexes{
    my $self=shift;
    my $job_filter = shift;
    my $job_map_hash = shift;
    my $JOB_NUM = shift;
    my @grouped_jobs = sort keys %$job_map_hash;
    my %job_group_order_hash ;
    my $group_order = 0;
    #my $util = App::Pipeline::Lite4::Util->new;            
      
    my %job_filter_hash = map{ $_ => 1 } @$job_filter;
    
    # construct hash [ job_num -> group_order] e.g { 0 -> 0 , 1 -> 0, 2 -> 0, 3 -> 1, 4 -> 1  }
    foreach my $grouped_jobs (@grouped_jobs){
        my $jobs_in_group = $job_map_hash->{$grouped_jobs};
        foreach my $job_in_group (@$jobs_in_group){
            $job_group_order_hash{$job_in_group} = $group_order;
        }
        $group_order++;
    }
    # leave only the executed jobs
    foreach my $job (keys %job_group_order_hash){
        unless( exists( $job_filter_hash{$job} ) ){
            delete $job_group_order_hash{$job};
        }
    }
    my @sorted_groups_in_job_filter = sort {$a<=>$b} values(%job_group_order_hash);
    my @groups_in_job_filter = App::Pipeline::Lite4::Util::uniq( @sorted_groups_in_job_filter );
    #warn Dumper @groups_in_job_filter;
    my %job_group_order_exec_hash;
    my $i=0;
    foreach my $job ( sort{ $a <=> $b} keys %job_group_order_hash){
        if(defined $groups_in_job_filter[$i]){
            $job_group_order_exec_hash{$job} = $groups_in_job_filter[$i];
        }else{ # higher jobs just get the first group
            $job_group_order_exec_hash{$job} = 0; 
        }
        $i++;
    }
    #warn Dumper "job exec group: ";
    #warn Dumper %job_group_order_exec_hash;
    # if JOB_NUM is executed
    if( exists( $job_group_order_exec_hash{$JOB_NUM} ) ){
        return $job_group_order_exec_hash{$JOB_NUM};
    }else{
        return 0;
    }    
}


=method 
# For a placeholder such as [% step1.myfilename %], this function generates a full pathname that will be substituted for this placeholder
# ( e.g  "/home/user/pipelineA/output/run1/step1/myfilename")
#
#  Each job can have one to multiple steps. Each step can have several placeholders. This function handles (for any particular job) 
#  transforming (resolving) the placeholder into actual pathname(s). 
#  There are currently three placeholder cases:
#     1. stepX.fileY  --> gets resolved to a single pathname
#     2. jobs.stepX.fileY  --> gets resolved to a list of pathnames 
#     3. groupby.groupby-field.stepX.fileY --> gets resolved to a list of pathname(s) dependent on the groupby field
#
#  Specifics:
#  case 1: 
#    a) Can have a "once condition" - meaning that the step commands will only be executed in one of the jobs(i.e. once).
#       A job number has to be chosen for this one execution, and the rule is that it's the minimum job number. 
#       This means generally when executing over a datasource, only the first job - job0 will contain the  
#       outputs from a step with a once condition.

Essential to remember that this function is being called for every job in the datasource:
Grp  jobid  jobs-executed   
  A  0 -->             
  B  1 -->   x            
  A  2 -->                 
  A  3 --> 
  B  4 -->   x
  C  5 -->   x 
Jobs are then filtered later to determine what actually gets executed. See the _resolve function.

Currently we do not support properly groupby under job filtering. Some work towards this is in the get_grouping_indexes function.

The way it seems like this might work is:
   1. Resolve the right groupby paths - and put them in the first g jobs (g the number of groups)
      This would entail running the first four jobs on groupby steps. This seems a little messy because the job filtering function will
      remove jobs that are not specified to run.  We would have to add an exception to the appropriate job purging function, to ensure that
      group by steps are saved.
    
=cut

sub _add_steps_in_step_struct_to_placeholder_hash {
    #TYPES: ( Num :$job_num ){
    my $self = shift;
    my $JOB_NUM = shift;
    my $step_struct = $self->pipeline_step_struct; # we have placeholders parsed for each step

    #warn "JOB_NUM $JOB_NUM";
    foreach my $step_name (keys %$step_struct ){
        $self->logger->log( "debug", "Processing Pipeline to placeholder hash step " . $step_name);
        my $placeholders = $step_struct->{$step_name}->{placeholders};
        next unless defined($placeholders);
        foreach my $placeholder ( @$placeholders ) {
            # A placeholder that references step A, should be mentioned in step A.
            # So we do not need to worry about it if it appears in other steps.
            # Thus we only process the placeholders in step X that mention step X.
            my $placeholder_resolved_str;
            my @output_run_dir;
            
           #==== case 1. stepX.fileY ====
           $self->logger->debug("step $step_name. Processing $placeholder");
           my $placeholder_rgx = qr/^($step_name)(\.(.+))*$/;
           if( @output_run_dir = $placeholder =~ $placeholder_rgx ){
               $self->logger->debug("step $step_name. Got " . Dumper(@output_run_dir) . " from $placeholder");
               # we don't want [1] - the dot, so @output_run_dir is 2 length array
               @output_run_dir = @output_run_dir[0,2];
               if( defined $output_run_dir[1] ){ 
                   # if the 2nd element is defined e.g. normally a filename like note.txt                 
                   $placeholder_resolved_str = $self->_generate_file_output_location($JOB_NUM, \@output_run_dir)->stringify;                  
               }elsif (  defined $output_run_dir[0]  ) {
                   #case where only the step name exists
                   pop @output_run_dir; # remove last entry because if second element is not defined array = ("stepname",undef) 
                   $placeholder_resolved_str = $self->_generate_file_output_location($JOB_NUM, \@output_run_dir)->stringify;
                   #warn "PLACEHOLDER", $placeholder;
                   #warn "OUTPUT RUN DIR (NORMAL PLCHOLDER) ". Dumper @output_run_dir;
                   #warn "OUTPUTFILES(NORMAL PLCHOLDER) ".$output_files;
               }
               $self->logger->debug("step $step_name. Extracted a run dir from: @output_run_dir. Full path is $placeholder_resolved_str ");
           }
            

           #==== case 2. jobs.[stepX|datasource].[fileY|datasource_column] ====
           # To resolve this form of placeholder we need to generate a list of resolved placeholder paths over ALL jobs 
           my $jobs_placeholder_rgx = qr/jobs\.([\w\-]+)\.(.+)$/;
           if(@output_run_dir = $placeholder =~ $jobs_placeholder_rgx){
              
               my @placeholder_resolved_paths; # all the placeholder resolved paths
               my $num_of_jobs = $self->tot_jobs;
               for my $job_num ( 0 .. $num_of_jobs -1 ) {
                    if( $output_run_dir[0] eq 'datasource' ) {
                      my $t = $self->pipeline_datasource;
                      my @datasource_rows = $t->col( $output_run_dir[1] );
                      push(  @placeholder_resolved_paths,$datasource_rows[$job_num] );
                    }else{
                      push(  @placeholder_resolved_paths,
                            $self->_generate_file_output_location(
                                $job_num, \@output_run_dir)->stringify );
                    }
               }
               # JOB FILTER: If we are running with specific job numbers, then we want only those paths associated
               #             with those job numbers.
               my $job_filter = $self->job_filter;
               @placeholder_resolved_paths =  @placeholder_resolved_paths[@$job_filter] if defined ( $job_filter );
               $placeholder_resolved_str = join ' ',  @placeholder_resolved_paths;
               $self->logger->debug("step $step_name. Extracted a run dir from: @output_run_dir. Full path is $placeholder_resolved_str");
           }


            #==== case 3. groupby.groupby-field.[stepX|datasource].fileY
            #  * you must groupby wrt a datasource column name. 
            #      - So access the datasource and check whether the field name is relevant
            #      - Figure out which resolved paths belong to each group
            #  * For two groups (g=2) - the rule is that these are executed in the first g jobs. (job0,job1)
            # 
            #  * Thus far we do not yet handle groupby when there are job filters   
            
            if( $placeholder =~ /groupby/ ){  
               my $groupby_placeholder_rgx;
               # get the datasource
               my $col_names = $self->pipeline_datasource->{header};
               #warn "WORKING WITH DATASOURCE: " . $self->datasource_file; #warn "DATASOURCE: " . Dumper $self->pipeline_datasource;
               my $col_names_rgx_str = join "|", @$col_names;
               my $groupby_placeholder_rgx_str = 'groupby\.('.$col_names_rgx_str . ')\.(' . $col_names_rgx_str . ')*\.*([\w\-]+)\.(.+)$';
               #warn "PLACEHOLDER $placeholder"; #warn "PLACEHOLDER RGX:", $groupby_placeholder_rgx_str;
               $groupby_placeholder_rgx = qr/$groupby_placeholder_rgx_str/;
               my @output_run_dir = $placeholder =~  $groupby_placeholder_rgx;
               #warn "PLACEHOLDER PARTS:", Dumper @output_run_dir;

               # Allows two groupby fields, here we check if the second groupby field is present
               my @group_names;
               if ( defined $output_run_dir[1] ){
                   @group_names = @output_run_dir[0,1];
                   @output_run_dir = @output_run_dir[2 .. $#output_run_dir];
               }else{
                   @group_names = $output_run_dir[0 ];
                   @output_run_dir = @output_run_dir[2 .. $#output_run_dir];
               }
                # warn "OUTPUTDIR @output_run_dir";
               if ( ! defined $output_run_dir[0] ){
                   ouch 'App_Pipeline_Lite4_ERROR', "The groupby placeholder has a group name that does not exist in the datasource";
               }

               #warn "OUTPUTDIR", "@output_run_dir";#warn "GROUP NAMES: @group_names";
               my $util = App::Pipeline::Lite4::Util->new;            
               my $job_map_hash = $util->datasource_groupby2( $self->pipeline_datasource, @group_names );
               # This gives a hash e.g.: {groupA=> [0,1,2,3], groupB=>[4,5,6]}
               #warn Dumper $job_map_hash;
                            
               my $job_filter = $self->job_filter;
               my %job_filter_hash = map{ $_ => 1 } @$job_filter if defined($job_filter);
               
               # order the groupnames - so that we always have the same groups in the same jobs
               my @grouped_jobs = sort keys %$job_map_hash;
               my $grouped_job_idx;               
               $grouped_job_idx = ($JOB_NUM <= $#grouped_jobs) ? $JOB_NUM : 0;
               
               # if there is a job filter then we have to get the right group index 
               if( defined $job_filter){
                   $grouped_job_idx = $self->get_grouping_indexes($job_filter,$job_map_hash,$JOB_NUM); 
               }
               
               # resolve for this placeholder the set of paths corresponding to the particular group associated with this JOB_NUM                             
               my $grouped_jobs_id = $grouped_jobs[ $grouped_job_idx ];
               my @placeholder_resolved_paths;
               my $jobs = $job_map_hash->{$grouped_jobs_id};
               
               for my $job_num ( @$jobs){
                   if( defined($job_filter) ){ 
                       #skip adding into @placeholder_resolved_paths if job is in job filter
                       next unless exists($job_filter_hash{$job_num} );
                   }
                   if( $output_run_dir[0] eq 'datasource' ) {
                      my $t = $self->pipeline_datasource;
                      my @datasource_rows = $t->col( $output_run_dir[1] );
                      push( @placeholder_resolved_paths,$datasource_rows[$job_num] );
                  }else{
                      push( @placeholder_resolved_paths, $self->_generate_file_output_location($job_num, \@output_run_dir)->stringify );
                  }  
               }
               $placeholder_resolved_str = join ' ', @placeholder_resolved_paths;
               #warn "STEPFILES: $output_files";
            }
            # add to placeholder hash - if there is something to add
            if( defined( $placeholder_resolved_str ) ){
                $self->_placeholder_hash_add_item( $placeholder, $placeholder_resolved_str); #in order key,value
                $self->logger->debug("step $step_name. Generated file location for placeholder $placeholder as $placeholder_resolved_str");
            }
         }
   }
   #warn Dumper $self->placeholder_hash;
}

=method 
    clean up of _add_steps_in_step_struct_to_placeholder_hash
    we will handle three types of steps here:
      * Normal Steps
      * Groupby Steps
      * Once Steps
      
    Under each of these steps we need to handle the placeholders differently
      *Normal Steps:
         - steps that originated from previous step types:
             Normal Step Placeholder  - fine
             Once Step Placeholder    - fine
             Groupby Step Placeholder - not fine - in future it might be possible to refer to a groupby class
         - jobs. placeholder        - fine
         - groupby placeholder      - fine?  - should not be fine
      *Groupby Steps
         - steps that originated from previous step types:
             Normal Step Placeholder  - not fine 
             Once Step Placeholder    - fine
             Groupby Step Placeholder - fine under certain circumstances
         - jobs. placeholder        - fine
         - groupby placeholder      - fine with condition 
        
=cut

sub _add_steps_in_step_struct_to_placeholder_hash2 {
    #TYPES: ( Num :$job_num ){
    my $self    = shift;
    my $JOB_NUM = shift;
    my $step_struct = $self->pipeline_step_struct; # we have placeholders parsed for each step

    #warn "JOB_NUM $JOB_NUM";
    foreach my $step_name (keys %$step_struct ){
        $self->logger->log( "debug", "Processing Pipeline to placeholder hash step " . $step_name);
        my $placeholders = $step_struct->{$step_name}->{placeholders};
        next unless defined($placeholders);
        
        # NORMAL STEPS WITH NO CONDITIONS
        if( !defined( $step_struct->{$step_name}->{condition} ) ){
            $self->_add_NORMALSTEP_in_step_struct_to_placeholder_hash($step_name, $JOB_NUM);
        }
        
       
        
        
    }
}

sub _add_ONCESTEP_in_step_struct_to_placeholder_hash {
    my $self = shift;
    my $step_struct = shift;
}
sub _add_GROUPBYSTEP_in_step_struct_to_placeholder_hash {
    my $self = shift;
    my $step_struct = shift;
}


=method
=cut
sub _add_NORMALSTEP_in_step_struct_to_placeholder_hash {
    my $self = shift;
    my $step_name = shift;
    my $JOB_NUM = shift;
    my $step_struct = $self->pipeline_step_struct;
    my $placeholders = $step_struct->{$step_name}->{placeholders};
    #next unless defined($placeholders);
    
    foreach my $placeholder ( @$placeholders ) {
        my $placeholder_resolved_str;
        # normal steps of type stepx.file1 or whatever
        #  these can still come from several types of other steps though 
        if ($self->_placeholder_step_form($placeholder,$step_name) eq 'step.path' ){           
            if( !defined ( $step_struct->{$step_name}->{condition})){
                $placeholder_resolved_str=$self->_resolve_normal_step_placeholder($placeholder,$step_name, $JOB_NUM);
            }elsif ($step_struct->{$step_name}->{condition} = 'once' ) {
                # add the minimum job number
            }elsif ($step_struct->{$step_name}->{condition} = 'groupby' ){
                # ouch
            }
        }
        # jobs form placeholders
          # allowed but this will get done for every job 
        # groupby form placeholders
          # not allowed
        # add to placeholder_hash  
        if( defined( $placeholder_resolved_str ) ){
                $self->_placeholder_hash_add_item( $placeholder, $placeholder_resolved_str); #in order key,value
                $self->logger->debug("step $step_name. Generated file location for placeholder $placeholder as $placeholder_resolved_str");
        }
    }
    warn "HERE WE ARE YOU JOKERS";
}

#sub _placeholder_step_type {
#    my $self = shift;
#    return  
#}


# we can have steps of 
#  * step.path
#  * groupby.field.step.path 
#  * jobs.step.path 

sub _placeholder_step_form {
    my $self = shift;
    my $placeholder = shift;
    my $step_name   = shift;
    my $placeholder_rgx = qr/^($step_name)(\.(.+))*$/;
    
    if($placeholder =~ $placeholder_rgx ){
        return "step.path";
    }
    
    my $jobs_placeholder_rgx = qr/jobs\.([\w\-]+)\.(.+)$/;
    if($placeholder =~ $jobs_placeholder_rgx){
        return "jobs";    
    }
    
    if( $placeholder =~ /groupby/ ){  
        return "groupby";
    }
}

#HERE TOO - just make this acceptable
sub _resolve_normal_step_placeholder {
    my $self = shift;
    my $placeholder = shift;
    my $step_name   = shift;
    my $JOB_NUM     = shift;
    my $placeholder_resolved_str;
    my @output_run_dir;
            
    #==== case 1. stepX.fileY ====
    $self->logger->debug("step $step_name. Processing $placeholder");
    my $placeholder_rgx = qr/^($step_name)(\.(.+))*$/;
    @output_run_dir = $placeholder =~ $placeholder_rgx ;
    $self->logger->debug("step $step_name. Got " . Dumper(@output_run_dir) . " from $placeholder");
    # we don't want [1] - the dot, so @output_run_dir is 2 length array
    @output_run_dir = @output_run_dir[0,2];
    if( defined $output_run_dir[1] ){ 
            # if the 2nd element is defined e.g. normally a filename like note.txt                 
           $placeholder_resolved_str = $self->_generate_file_output_location($JOB_NUM, \@output_run_dir)->stringify;                  
    }elsif (  defined $output_run_dir[0]  ) {
           #case where only the step name exists
           pop @output_run_dir; # remove last entry because if second element is not defined array = ("stepname",undef) 
           $placeholder_resolved_str = $self->_generate_file_output_location($JOB_NUM, \@output_run_dir)->stringify;
           #warn "PLACEHOLDER", $placeholder;
           #warn "OUTPUT RUN DIR (NORMAL PLCHOLDER) ". Dumper @output_run_dir;
           #warn "OUTPUTFILES(NORMAL PLCHOLDER) ".$output_files;
    }
    $self->logger->debug("step $step_name. Extracted a run dir from: @output_run_dir. Full path is $placeholder_resolved_str ");
    return $placeholder_resolved_str;
}




=method _create_directory_structure_from_placeholder_hash
  At the moment we  allow directory with 'dir' in the name
  to be created as a directory - e.g. for this scenario
  e.g. 1. some_app --output-dir [ step1.dir ]
  Where some_app requires a pre-existing directory for storing it's output
  We could resolve this issue without using this.
  By doing:
  1. mkdir [% step1.outputdir %]; some_app --output-dir [% step1.outputdir %]
  So it's debatable whether we want automatic creation of directories with 'dir' in the name,
  but will leave for backwards compatability
  THE DIR BEHAVIOUR SHOULD BE DEPRECATED
=cut

sub _create_directory_structure_from_placeholder_hash {
    my $self = shift;
    $self->logger->debug("Creating directory structure from placeholder hash...");
    # run over hash
    my $placeholder_hash = $self->placeholder_hash;
    $self->logger->debug(Dumper($placeholder_hash));
    foreach my $step (keys %$placeholder_hash ){
       next if( ($step eq 'step0') or ($step eq 'datasource')); # we don't create any directories from the source step values. (which could be filenames)
       next if( ($step eq 'groupby')); # don't make directory on a groupby
       foreach my $param (keys $placeholder_hash->{$step} ){
           if ($param =~ /dir/) {
               my $dir = path( $placeholder_hash->{$step}->{$param} );
               #make_path($dir->stringify);
               $dir->mkpath;
               $self->logger->debug("Making directory: $dir" );
           } else {
              my $file = path( $placeholder_hash->{$step}->{$param} );
              #make_path($file->parent->stringify);
              $file->parent->mkpath;
              $self->logger->debug("Making directory (step $step): " . $file->parent->stringify );

           }
       }
    }
}

# processing the "X.output file1 file2 .."  lines
sub _add_expected_output_files_to_placeholder_hash {
     # TYPE: ( Num :$job_num )
     my $self = shift;
     my $job_num = shift;
     my $step_struct = $self->pipeline_step_struct; # we have outputfiles parsed for each step
     foreach my $step_name (keys %$step_struct ){
        $self->logger->debug( "Processing expected output file for Step: " . $step_name);
        $self->logger->debug("Make filepaths and placeholder hash entry for stated outputs of step $step_name");
        my $file_num = 1;
        $self->logger->debug("So far there are " . ($file_num - 1) . " file(s) registered as outputs for this step");
        my $outputfiles = $step_struct->{$step_name}->{outputfiles};
        if( defined( $outputfiles) ) {
            foreach my $outputfile ( @$outputfiles ) {
                  #output_path_in_run_dir should be output_path_in_job_dir
                  #check whether the file_path is absolute, if its absolute then we don't generate anything for it
                 # if($step_name =~ /^[1-9][0-9]*[a-z]*$/){
                 #   my $file_path = $self->_generate_file_output_location( $job_num, ['step'. $step_name , $outputfile] );
                 #   $self->placeholder_hash->{"step$step_name"}{"output$file_num"}=$file_path->stringify;
                 #   $self->logger->debug( "Made step$step_name output$file_num : " . $file_path->stringify);
                 #   $file_num++;
                 # }else{
                    my $file_path = $self->_generate_file_output_location( $job_num, [ $step_name , $outputfile] );
                    $self->placeholder_hash->{"$step_name"}{"output$file_num"}=$file_path->stringify;
                    $self->logger->debug( "Made $step_name output$file_num : " . $file_path->stringify);
                    $file_num++;
                 # }
            }
        }
     }
}

sub _add_expected_output_files_to_jobs_in_placeholder_hash {
    my $self = shift;
    #get the expected output files
    my $step_struct = $self->pipeline_step_struct;
    my $placeholder_hash = $self->placeholder_hash;
    return if( ! exists $placeholder_hash->{jobs} );
    my $jobs = $placeholder_hash->{jobs};
    foreach my $step (keys %$jobs){
       next if $step eq 'datasource';
       my $filenames_and_paths = $jobs->{$step};
       my @filenames = keys %$filenames_and_paths;
       foreach my $filename (@filenames){
         my ($output_num) = $filename =~ /output([0-9]+)/;
         next unless defined( $output_num);
         my $outputfiles = $step_struct->{$step}->{outputfiles};
         my $name_of_output_file  = $outputfiles->[$output_num-1];
         $filenames_and_paths->{$filename}  =~ s/output$output_num/$name_of_output_file/g;
       }
    }
}

=method _validate_placeholder_with_placeholders

   What happens if you add a non existant placeholder e.g. [% step0.fil %] ?
   The parser has parsed out this placeholder - so it is part of the step_struct placeholders for each step
   But, it won't have a corresponding value in the placeholder hash, since it not of the right form.
   Not having a value, might be desired behaviour for somethings (this could be warned),
   But not existing in the hash is an error.

=cut

sub _validate_placeholder_hash_with_placeholders {
   my $self = shift;
   #foreach step check that we have the right stuff in the placeholder hash
    my $step_struct = $self->pipeline_step_struct;
    my %problem_placeholders;
    foreach my $step_name ( keys %$step_struct) {
       my $placeholders = $step_struct->{$step_name}->{placeholders};
       $self->logger->debug( "Validating Step: " . $step_name);
        foreach my $placeholder (@$placeholders) {
           #if($placeholder =~ /^datasource\./){
           #   ($placeholder ) = $placeholder =~ /datasource\.(.+)$/;
           #}
           #ouch 'App_Pipeline_Lite2_Error', "Check the placeholder $placeholder - it is incorrectly named."
           #  . Dumper ($self->placeholder_hash)
           #  unless $self->_placeholder_hash_check_item_exists( keystr => $placeholder );
           $problem_placeholders{ $placeholder } = 1  unless $self->_placeholder_hash_check_item_exists(  $placeholder );;
        }
    }
    my @problem_placeholders = keys %problem_placeholders;
    my $problem_placeholders = join "\n", @problem_placeholders ;
    ouch 'App_Pipeline_Lite4_Error_MISSING_PLACEHOLDER', "Check the placeholders:\n$problem_placeholders\n"
             if @problem_placeholders > 0;

}

sub _interpolate_cmd_in_step_struct_to_resolved_step_struct {
    # ( Num :$job_num ) {
    my $self = shift;
    my $job_num = shift;
    my $step_struct = $self->pipeline_step_struct;
    $self->logger->debug("Step struct has : " . Dumper( $step_struct ));
    $self->logger->debug("Placeholder hash has : " . Dumper ( $self->placeholder_hash ) );
    my %output_hash;
    my $interpolated_cmd;
    my $interpolated_output;
    my $new_step_struct = dclone($step_struct);
    my $tt = App::Pipeline::Lite4::Template::TinyMod->new;
    foreach my $step ( keys %$step_struct) {
       my $cmd = $step_struct->{$step}->{cmd};
       $interpolated_cmd = $tt->_process($self->placeholder_hash, $cmd);
       $new_step_struct->{$step}->{cmd} =$interpolated_cmd;
       $interpolated_cmd = '';

       #also do for output line

       if( exists $step_struct->{$step}->{outputfiles} ){
           my $output_files = $step_struct->{$step}->{outputfiles};
            $new_step_struct->{$step}->{outputfiles} = [];
           foreach my $output (@$output_files){
               $interpolated_output = $tt->_process($self->placeholder_hash, $output);
               my $outputfiles = $new_step_struct->{$step}->{outputfiles};
               push(@$outputfiles, $interpolated_output); #CHECK THIS IN TEST
               $interpolated_output = '';
           }
       }
    }
    $self->pipeline_step_struct_resolved->{$job_num} = $new_step_struct;
}


sub _placeholder_hash_check_item_exists{
    # TYPE: Str :$keystr
    my $self = shift;
    my $keystr = shift;
    my @keystr = ();
    @keystr = split('\.', $keystr) if ($keystr =~ /\./);
    return exists $self->placeholder_hash->{ $keystr } if( @keystr == 0);

    if( $keystr[0] eq 'jobs'){
	  @keystr = ( $keystr[0], $keystr[1], join('.', @keystr[2 .. $#keystr]  ) );
	}else {
      @keystr = ( $keystr[0], join('.', @keystr[1 .. $#keystr]  ) );
	}

    return exists $self->placeholder_hash->{ $keystr[0] }{ $keystr[1] } if @keystr == 2;
    return exists $self->placeholder_hash->{ $keystr[0] }{ $keystr[1] }{ $keystr[2] } if @keystr == 3;
}

sub _once_condition_filter_on_resolved_step_struct {
   my $self = shift;
   my $resolved_step_struct = $self->pipeline_step_struct_resolved;
   my @keys = sort {$a <=> $b } keys %$resolved_step_struct;
   shift @keys; #remove the lowest job
   $self->logger->debug("Deleting once steps in these steps: @keys");
   foreach my $job_num (@keys){
       my $job = $resolved_step_struct->{$job_num};
       foreach my $step (keys %$job) {
          next unless ( exists  $job->{$step}->{condition}  );
          next unless ( defined $job->{$step}->{condition}  );
          if ( $job->{$step}->{condition} eq 'once') {
                $self->logger->debug("Deleting once step in $job_num");
                delete $job->{$step};
          }
       }
   }
}

sub _groupby_condition_filter_on_resolved_step_struct {
    my $self = shift;
    my $resolved_step_struct = $self->pipeline_step_struct_resolved;
    my @keys = sort {$a <=> $b } keys %$resolved_step_struct;
    # need to get the number of jobs to shift off.
    my $util = App::Pipeline::Lite4::Util->new;

    #shift @keys for 0 .. $num_grouped_jobs - 1; #remove the X lowest jobs depending on the step groupby clause
    $self->logger->debug("Consider deleting groupby steps in these steps: @keys");
    foreach my $job_num (@keys){
       my $job = $resolved_step_struct->{$job_num};
       foreach my $step (keys %$job) {
          next unless ( exists  $job->{$step}->{condition}  );
          next unless ( defined $job->{$step}->{condition}  );
          if ( $job->{$step}->{condition} eq 'groupby') {
                my $params = $job->{$step}->{condition_params};
                my $num_grouped_jobs = $util->datasource_groupby2_num_groups($self->pipeline_datasource, @$params);
                if( $job_num >= $num_grouped_jobs){
                    $self->logger->debug("Deleting groupby step $step in $job_num");
                    delete $job->{$step};
                }
          }
       }
   }
}



sub _generate_file_output_location {
   # TYPE:( :$job_num, :$output_path_in_run_dir )
   my ($self, $job_num, $output_path_in_run_dir) = @_;
   if ( defined $self->run_num_dep ) {
      my $steps = $self->step_filter;

      #### WE WANT ANY####
      my $code = sub { my $k = shift; return 1 if( $output_path_in_run_dir->[0] eq $k ); return 0;   };
      my $valid_step = reduce { $a || $code->(local $_ = $b)  } 0,  @$steps;
      # my $valid_step = any{ ($output_path_in_run_dir->[0] =~ $_) } @$steps;
      ###############

      if ( !$valid_step ) {
       my $alt_run_dir = path( $self->output_dir, $self->output_run_name . ($self->run_num_dep) );
       return path( $alt_run_dir , $self->output_job_name .  $job_num, @$output_path_in_run_dir );
      }
   }
   return path( $self->current_run_dir , $self->output_job_name .  $job_num, @$output_path_in_run_dir );
   # return file( $self->output_dir, 'run' . ($self->current_run_num) , $self->output_job_name .  $job_num, @$output_path_in_run_dir );
}

=method _run_number
   Provides the last run number by looking at previous run directory numbers
=cut
## THIS IS IN BASE NOW - REMOVE
sub _last_run_number {
    my $self=shift;
    #read in files in data directory
    #order by run number
    # - if none then run number is 1.
    my $run_num = max map { if( $_ =~ /run([0-9]+)/){$1}else{} } $self->output_dir->children;
    $run_num = 0 unless (defined $run_num);
    return $run_num;
}
1;