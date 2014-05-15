use strict;
use warnings;
package App::Pipeline::Lite4::Command::file;
use Moo;
use Ouch;
use App::Pipeline::Lite4::Resolver;
use Path::Tiny;
use Sort::Naturally;
use Number::Bytes::Human qw(format_bytes);
use Time::Piece;
use Data::Table;
sub execute {
    my ($self, $opt, $args) = @_;
 
    
    eval {
       
       # set show steps if stats
       $opt->{step_name} = 1 if $opt->{stats};
        
       # Default is to get the latest run and the latest datasource
   
      my $resolver = App::Pipeline::Lite4::Resolver->new( pipeline_dir =>  $args->[0]); 
      my $run_num = $resolver->_last_run_number;           
       if( defined $opt->{run_num} ) {
          $run_num = $opt->{run_num};
       }
      
      #get datasource from settings directory and set to datasource file
      $resolver->datasource_file( $resolver->datasource_from_run($run_num) );
      my $datasource = $resolver->pipeline_datasource;
      #print $datasource->tsv;
       
      # Go through each job  
          # create a hash based on steps 
          #  $steps{step}{filename}{jobnum}
          #  then  at the end  
      my $output_run_dir = path( $resolver->output_dir, "run".$run_num);
 
      my $iter = $output_run_dir->iterator( { recurse => 1 } );
      my %step_hash;
      my %jobs;
      while( my $path = $iter->() ){        
        next unless $path->is_file;
        next if(  $path->basename =~ m{/?(out|err)$} ); 
        next unless $path =~ /job/; #removes setting directory and other things that are not jobs
        
        #print $path . "\n";
        my ($job, $step,$name)  = $path->stringify =~ m{(job[0-9]+)/(.+)/(.+)$};
        #my ($step) = $path->stringify =~ m{job[0-9]+/(.+)/} ;
        #print join " ", $job, $step, $name .  "\n";
        if( $opt->{stats} ){
           my $time = localtime($path->stat->mtime)->datetime;
           $step_hash{$step}{$name}{$job} = format_bytes( $path->stat->size) . "," . "[$time]";
        }else{
          $step_hash{$step}{$name}{$job} = $path;
        } 
        $jobs{$job} =1;
      }  
     
      #print header
      
      my @row;
      my $header;
      foreach my $step (nsort keys %step_hash){
        my $names = $step_hash{$step};
        foreach my $name (nsort keys %$names){
           if( $opt->{step_name} ){
             push @row,  $step."-".$name;
           }else{
             push @row,  $name;
           }
        }
      }
      
      #print join "\t", @row; print "\n";
      $header = [@row];
      
      my @table_data;
      foreach my $job (nsort keys %jobs){  
          @row = ();
          # go through each step and if the name doesn't have this job then put in some null character          
          foreach my $step (nsort keys %step_hash){
              my $names = $step_hash{$step};
              foreach my $name (nsort keys %$names){
                  if( exists $names->{$name}->{$job} ){                  
                   push @row,  $names->{$name}->{$job} 
                }else{
                  push @row,"-";
                }
                                 
              }
          }
          #print join "\t", @row; print "\n";
          push @table_data, [@row];
       }
       
      my $t = Data::Table->new(\@table_data, $header, 0);
      $datasource->colMerge($t, {renameCol => 1 } );
      print $datasource->tsv;
       
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