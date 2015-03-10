use strict;
use warnings;
package App::Pipeline::Lite4::Command::symlink2;
use Moo;
use Ouch;
use App::Pipeline::Lite4;
use App::Pipeline::Lite4::Resolver;
use Path::Tiny;
use Sort::Naturally;

sub execute {
    my ($self, $opt, $args) = @_;

     eval {
        my $pipeline_dir =   path($args->[0]);
        my $App_Pipeline_Lite = App::Pipeline::Lite4->new( pipeline_dir => $args->[0]);      
        my $run_num = $App_Pipeline_Lite->last_run_num;
        if(defined $opt->{run_num}){     
           $run_num = $opt->{run_num};
        }
        $App_Pipeline_Lite->run_num($run_num);        
        my $datasource_path = $App_Pipeline_Lite->datasource_from_run($run_num);
        $App_Pipeline_Lite->datasource_file($datasource_path);
        if(defined $opt->{datasource} ){
            $App_Pipeline_Lite->datasource_file($opt->{datasource});
        }
        $App_Pipeline_Lite->symlink($opt);       
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