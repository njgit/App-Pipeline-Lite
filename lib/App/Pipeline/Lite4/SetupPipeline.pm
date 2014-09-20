use strict;
use warnings;
package App::Pipeline::Lite4::SetupPipeline ;
use Moo;
use MooX::late;

extends 'App::Pipeline::Lite4::Base';
use Ouch;
use Path::Tiny;
use YAML::Any;
 
sub create_pipeline_directory {
    my $self=shift;
    my $based_on = shift; # PARAMETER TYPE: ( Path::Tiny $based_on? ) i.e. optional 
    
    my $dir             = $self->pipeline_dir;
    my $output_dir      = $self->output_dir;
    my $input_dir       = $self->input_dir;
    my $pipeline_file   = $self->pipeline_file;
    my $test_data_file  = $self->test_data_file;
    my $datasource_file = $self->datasource_file;
    my $software_dir    = $self->software_dir;
    my $sys_dir         = $self->sys_dir;
    ouch 'App_Pipeline_Lite4_Error', "That pipeline already exists."  if $dir->exists;
    $dir->mkpath();  
    $output_dir->mkpath();
    $input_dir->mkpath();
    $software_dir->mkpath();
    $sys_dir->mkpath();
    
    #set output file and read to config file
    $self->config->{_}->{output_dir} = $output_dir->absolute->stringify;
    $self->config->{_}->{input_dir}  = $input_dir->absolute->stringify;

    $self->config->write($self->config_file->absolute->stringify); 
    
    #create a small pipeline file and a dummy test data directory
 
    $pipeline_file->spew("seq. seq [% datasource.N %] | grep -v ‘[% datasource.filter %]’ > [% seq.filterseq.txt %]");
    $test_data_file->parent->mkpath();
    #$test_data_file->spew("line1\nline2\nline3");    
my $ds = "N\tfilter\tgroup\tname
12\t5|6\tA\tjames
15\t7|8\tB\tnozomi
16\t9|10\tA\tryan
20\t12|13\tB\ttiffiny";
     
    #create a small datasource file
    #my $datasource = "step0.file1\n" . $test_data_file->absolute->stringify;
    $datasource_file->spew($ds);
    $self->create_logfile_config;
}


sub create_logfile_config {
   my $self = shift; 
   my $default = 
   { 
     file => {
              filename => defined($self->logfile) ? $self->logfile : "/tmp/".__PACKAGE__.".log",
              maxlevel => "debug",
              minlevel => "warning",
              message_layout => "%T [%L] [%p] line %l: %m",
            }
   };
   my $conf_yaml  = Dump($default);
   $self->logconffile->spew($conf_yaml);  
}
1;