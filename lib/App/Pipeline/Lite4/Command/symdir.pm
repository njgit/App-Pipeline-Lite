use strict;
use warnings;
package App::Pipeline::Lite4::Command::symdir;
use Moo;
use Ouch;
use App::Pipeline::Lite4;

 sub execute {
    my ($self, $opt, $args) = @_;
    
     # get pipeline directory
     # get pipelite object 
    
     eval {
        my $App_Pipeline_Lite = App::Pipeline::Lite4->new( pipeline_dir => $args->[0]);
   
        my ($step,$filename) = split '#', $opt->{step_and_fname} ;
        
        # get the datasource  
        my $resolver = App::Pipeline::Lite4::Resolver->new( pipeline_dir =>  $args->[0]); 
        my $run_num = $resolver->_last_run_number;           
        if( defined $opt->{run_num} ) {
          $run_num = $opt->{run_num};
         }
      
        #get datasource from settings directory and set to datasource file
        $resolver->datasource_file( $resolver->datasource_from_run($run_num) );
        my $datasource = $resolver->pipeline_datasource;
                
        my $output_run_dir = path( $resolver->output_dir, "run".$run_num);
        my @jobs =  grep { /job/ } $output_run_dir->children
        print "@jobs\n"; 
        #my $iter = $output_run_dir->iterator( { recurse => 1 } );
        #my %step_hash;
        #my %jobs;
        #while( my $path = $iter->() ){        
        #  next unless $path->is_file;
        #  next if(  $path->basename =~ m{/?(out|err)$} ); 
        #  next unless $path =~ /job/; #removes setting directory and other things that are not jobs
        #}
        
        
        # parse the step name and filename
        # check that the field exists
        # go through each job directory and make the link
        # if a file doesn't exist warn. 
        # make a datasource for the symlink files
            
     };
    
     if( kiss 'App_Pipeline_Lite4_Error') {
       print bleep(), "\n"; 
     } elsif ( hug ) {
       print 'An error occurred, check logs: ', $@ ;
     }
}
1;