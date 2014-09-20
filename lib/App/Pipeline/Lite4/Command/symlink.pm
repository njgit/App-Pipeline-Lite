use strict;
use warnings;
package App::Pipeline::Lite4::Command::symlink;
use Moo;
use Ouch;
use App::Pipeline::Lite4;
use App::Pipeline::Lite4::Resolver;
use Path::Tiny;
use Sort::Naturally;

sub execute {
    my ($self, $opt, $args) = @_;

     eval {
        my $id_field = $opt->{id_field};
        my $pipeline_dir =       path($args->[0]);
        my $App_Pipeline_Lite = App::Pipeline::Lite4->new( pipeline_dir => $args->[0]);
        ouch 'App_Pipeline_Lite_CMD_ERROR', "Requires step_and_filename argument"
           unless ( defined( $opt->{step_and_fname} ) );
        my ($step,$filename) = split '#', $opt->{step_and_fname} ;
        
        ouch 'App_Pipeline_Lite_CMD_ERROR', "Something went wrong specifying the step and filename" 
           unless ( defined($step) and defined($filename));
        ouch 'App_Pipeline_Lite_CMD_ERROR', "Something went wrong specifying the step and filename" 
           if( $step eq '' or $filename eq '');
        
        # get the datasource  
        my $resolver = App::Pipeline::Lite4::Resolver->new( pipeline_dir =>  $args->[0]); 
        my $run_num = $resolver->_last_run_number;           
        if( defined $opt->{run_num} ) {
          $run_num = $opt->{run_num};
        }
        
        my $datasource;
        if( defined( $opt->{datasource} )){
          $resolver->datasource_file($opt->{datasource} );
          $datasource = $resolver->pipeline_datasource;
        }else{
          #get datasource from settings directory and set to datasource file
          $resolver->datasource_file( $resolver->datasource_from_run($run_num) );
          $datasource = $resolver->pipeline_datasource;
        }
         
        my $output_run_dir = path( $resolver->output_dir, "run".$run_num);
        my @jobs = nsort grep { /job/ } $output_run_dir->children;

        my @job_ids = map {$_->basename} @jobs;
        if( ! defined( $id_field) ){
           warn "No ID field defined. Prepending job numbers " 
        }elsif( $datasource->hasCol($id_field) ){
           @job_ids = $datasource->col($id_field);
        }else{
           warn "No matching ID field in datasource. Prepending job numbers"
        }
        
        #default path
        my $symlink_dir = path($resolver->symlink_dir, $step, $run_num);
        $symlink_dir = $opt->{path} if defined($opt->{path});
        $symlink_dir->mkpath;
        my @table_data;
        foreach my $job (@jobs){
          my $path = path($job,$step,$filename);
          my $id = shift @job_ids;
          if( $path->exists){
             my $new_basename = "$id-".$path->basename;
             if( defined( $opt->{name} )){
                my $name = $opt->{name};
                $new_basename = "$id$name" ;                                
             }             
             my $new_path = path($symlink_dir,$new_basename);
             symlink $path, $new_path->absolute;  
             print "symlinked $path to $new_path\n";
             push @table_data, [$new_path];
          }else{
             warn "path $path does not exist";
             push @table_data, ["-"];
          }
        }
        
        my $t = Data::Table->new(\@table_data, [$filename], 0);
        $datasource->colMerge($t);
        my $datasource_tsv = $datasource->tsv;
        my $datasource_path = path($symlink_dir,$pipeline_dir->basename . ".datasource");
        $datasource_path->spew($datasource_tsv);
        # parse the step name and filename
        # check that the field exists
        # go through each job directory and make the link
        # if a file doesn't exist warn. 
        # make a datasource for the symlink files            
     };
    
     if( kiss 'App_Pipeline_Lite4_Error') {
       print bleep(), "\n"; 
     } elsif ( kiss  'App_Pipeline_Lite_CMD_ERROR') {
       print bleep(), "\n";       
     }elsif ( hug ) {
       print 'An error occurred, check logs: ', $@ ;
     }
}
1;