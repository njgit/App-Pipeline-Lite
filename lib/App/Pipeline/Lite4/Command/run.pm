use strict;
use warnings;
package App::Pipeline::Lite4::Command::run;
use Moo;
use Ouch;
use Path::Tiny;
use App::Pipeline::Lite4;
sub execute {
    my ($self, $opt, $args) = @_;
    
    eval {
        # Initiate
        my $App_Pipeline_Lite = App::Pipeline::Lite4->new( pipeline_dir => $args->[0]);

        # Get options
        my $desc ="smoke-test";
        $desc = $App_Pipeline_Lite->util->ask_for_description
        unless defined $opt->{smoke_test};
        my $step_filter = $opt->{steps} // "*";
        my $job_filter  = $opt->{jobs} // "*";
        my $run_num =  $App_Pipeline_Lite->last_run_num + 1;
        $run_num = $opt->{run_num} if defined($opt->{run_num});
        my $run_info = join " ", "run" . "[ $run_num ]", "[ step-filter: " . $step_filter  . " ]", "[ job-filter: " . $job_filter . " ]";
        
        #Set Options
        $App_Pipeline_Lite->util->append_description( $run_info, $desc ); # Write Options to log
        
        $App_Pipeline_Lite->smoke_test(1) if defined($opt->{smoke_test});
        defined $opt->{steps} ? $App_Pipeline_Lite->step_filter_str($step_filter);
        defined $opt->{jobs} ? $App_Pipeline_Lite->job_filter_str( $job_filter );
        
        $App_Pipeline_Lite->run_num($run_num);
        
        # Get datasource from datasource if supplied, otherwise from runnum
        if( defined $opt->{datasource} ) {
            # pre check that file exists
            my $datasource_path = $opt->{datasource};
            ouch 'App_Pipeline_Lite4_Error', "The datasource path ($datasource_path) is not a file" unless path( $datasource_path)->is_file ;
            $App_Pipeline_Lite->datasource_file( $datasource_path )  ;
        } elsif( defined $opt->{run_num}){
            my $datasource_path = $App_Pipeline_Lite->datasource_from_run($run_num);
            ouch 'App_Pipeline_Lite4_Error', "The datasource path ($datasource_path) defined by run_num is not a file" unless path( $datasource_path)->is_file ;
            $App_Pipeline_Lite->datasource_file($datasource_path);
        }
        
        # Run the pipeline
        $App_Pipeline_Lite->run_pipeline;
        
    };
    
    if( kiss 'App_Pipeline_Lite4_Error') {
       print bleep(), "\n"; 
    } elsif ( kiss 'App_Pipeline_Lite4_Error_MISSING_PLACEHOLDER' ){
       print "\n*** There is something to fix before this pipeline can dispatch ***\n";
       print "\n", bleep(), "\n\n"; 
       print "This might be fixed by:\n
             - giving the placeholder a value (e.g. treating as an argument) via --args
             - fixing an error in the placeholder name
             - creating values for this placeholder in the datasource
        \n";
   }elsif ( hug ) {
       print 'An error occurred, check logs: ', $@ ;
    }
}
1;
