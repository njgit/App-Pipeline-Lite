use strict;
use warnings;
package App::Pipeline::Lite4::Command::new;
use Moo;
use MooX::late;
use Ouch;
use App::Pipeline::Lite4::SetupPipeline;

sub execute {
    my ($self, $opt, $args) = @_;
    # get pipeline directory
    # get pipelite object    
    eval {        
        my $App_Pipeline_Lite_Setup = App::Pipeline::Lite4::SetupPipeline->new( pipeline_dir => $args->[0]); 
        $App_Pipeline_Lite_Setup->output_dir( dir( $opt->{output_dir} ) ) if defined($opt->{output_dir});      
        if( defined $opt->{based_on}){
             $App_Pipeline_Lite_Setup->create_pipeline_directory( based_on => $opt->{based_on} ); # this needs to be written in setup            
        }else{
             $App_Pipeline_Lite_Setup->create_pipeline_directory();
        }        
    };
    
    if( kiss 'App_Pipeline_Lite2_Error') {
       print bleep(), "\n"; 
    } elsif ( hug ) {
       print 'An error occurred, check logs: ', $@ ;
    }
}
1;