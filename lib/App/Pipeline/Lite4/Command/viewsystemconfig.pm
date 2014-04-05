use strict;
use warnings;
package App::Pipeline::Lite4::Command::viewsystemconfig;
use Moo;
use Ouch;
use App::Pipeline::Lite4;

sub execute {
    my ($self, $opt, $args) = @_;
      
    
    eval {       
        my $App_Pipeline_Lite = App::Pipeline::Lite4->new;
        my $App_Pipeline_Lite_Util = App::Pipeline::Lite4::Util->new; 
        if(defined $opt->{editor}){               
                $App_Pipeline_Lite_Util->set_editor( $opt->{editor});
        }                             
        $App_Pipeline_Lite_Util->view_file_with_editor( $App_Pipeline_Lite->system_config_file );
    };
    
    if( kiss 'App_Pipeline_Lite4_Error') {
       print bleep(), "\n"; 
    } elsif ( hug ) {
       print 'An error occurred, check logs: ', $@ ;
    }
}
1;