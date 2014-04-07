use strict;
use warnings;
package App::Pipeline::Lite4::Command::run;
use Moo;
use Ouch;
use App::Pipeline::Lite4;
sub execute {
    my ($self, $opt, $args) = @_;
 
    
    eval {
        my $App_Pipeline_Lite = App::Pipeline::Lite4->new( pipeline_dir => $args->[0]);
        $App_Pipeline_Lite->datasource_file( $opt->{datasource}) if defined($opt->{datasource});   
        $App_Pipeline_Lite->smoke_test(1) if defined($opt->{smoke_test});    
        
        if( defined $opt->{steps} ) {
          $App_Pipeline_Lite->step_filter_str($opt->{steps});     
        }
        
        if(defined $opt->{jobs}){
           $App_Pipeline_Lite->job_filter_str( $opt->{jobs} );
        }
        
        if(defined $opt->{run}){
               
         $App_Pipeline_Lite->run_num($opt->{run});
        # set datasource from previous run_num?
        # $App_Pipeline_Lite->datasource_file
        # or do we set the $App_Pipeline_Lite->datasource_resolve_file
        # do we need a switch to say this is the resolved file 
        # and don't do any further datasource resolving?
      }
      
      my $desc ="smoke-test";  
      $desc = $App_Pipeline_Lite->util->ask_for_description
                      unless defined $opt->{smoke_test};
      my $step_filter = $opt->{steps} // "*";
      my $job_filter  = $opt->{jobs} // "*"; 
      my $run_num =  $App_Pipeline_Lite->last_run_num + 1; 
      $run_num = $opt->{run} if defined($opt->{run});    
      my $run_info = join " ", "run" . "[ $run_num ]", "[ step-filter: " . $step_filter  . " ]", "[ job-filter: " . $job_filter . " ]";
                
      $App_Pipeline_Lite->util->append_description( $run_info, $desc );   
        
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