use Test::More tests => 1;
use App::Pipeline::Lite4::Resolver;
use App::Pipeline::Lite4::Parser;
use Path::Tiny;
use Data::Dumper;
use YAML::Any;

my $pipeline_dir = path( qw(td test-pipeline-1) );

### MAKE THE DATASOURCE
my @files = map {path('td',$_)} qw(book.1609 book.3218 book.4827 book.6436 book.8045);
my $datasource = path('td/book.datasource');
my @lines;
push (@lines, join "\t", "name", "path\n");
foreach my $file ( @files ){
   my $line = join "\t", $file->basename, $file->absolute->stringify ."\n";
   push (@lines,$line);
}
$datasource->spew(@lines);
###

  
## NEED TO DO THIS BECAUSE RESOLVER NEEDS TO PICK UP ON THE PROCESSED YAML FILES IN THE PIPELINE DIR
my $parser = App::Pipeline::Lite4::Parser->new( pipeline_dir => path( qw(td test-pipeline-1) ) );
$parser->preparse(   $parser->pipeline_file,  
                     $parser->pipeline_preparse_file );
$parser->parse(  $parser->pipeline_preparse_file, 
                 $parser->pipeline_parse_file);
#####################################################################################################

my $App_Pipeline_Lite_Resolver = App::Pipeline::Lite4::Resolver->new(
    pipeline_dir => $pipeline_dir,
    run_id => 1,
    once_condition_filter => 0,
    use_relative_paths => 1,
    datasource_file => 'td/book.datasource'
    #output_dir => $pipeline_output_dir
);
$App_Pipeline_Lite_Resolver->_resolve;


#this will be the last of the datasource entries added to the placeholder hash
warn "PLACEHOLDER HASH STRUCTURE";
warn Dumper $App_Pipeline_Lite_Resolver->placeholder_hash;

warn "RESOLVED STEP STRUCTURE";
warn Dumper $App_Pipeline_Lite_Resolver->pipeline_step_struct_resolved;

ok(1);
=cut
my $expected_dir = dir( qw(td expected)  );
my $pipeline_dir = dir( qw(td pipeline2) );
my $pipeline_output_dir = dir( $pipeline_dir, qw(output) );
my $parser = App::Pipeline::Lite2::Parser->new( pipeline_dir => $pipeline_dir, output_dir => $pipeline_output_dir, append_err_str => 0,prepend_cwd_str => 0);
$parser->preparse( pipeline_file => $parser->pipeline_file,  
                   yaml_outfile => $parser->pipeline_preparse_file );
$parser->parse( yaml_infile  => $parser->pipeline_preparse_file, 
                yaml_outfile => $parser->pipeline_parse_file);

my $App_Pipeline_Lite2_Resolver = App::Pipeline::Lite2::Resolver->new(
    pipeline_dir => $pipeline_dir,
    run_id => 1,
    once_condition_filter => 0,
    use_relative_paths => 1,
    output_dir => $pipeline_output_dir
);

my $yaml_in  =  $App_Pipeline_Lite2_Resolver->pipeline_parse_file;
my $yaml_out =  $App_Pipeline_Lite2_Resolver->pipeline_resolved_file;

$App_Pipeline_Lite2_Resolver->current_run_num(1);
$App_Pipeline_Lite2_Resolver->resolve( yaml_infile => $yaml_in, yaml_outfile => $yaml_out );

# Functional Test on output
my $resolved_yaml = $yaml_out->slurp;
my $resolved = Load( $resolved_yaml );
my $expected_resolved_yaml = file($expected_dir, 'pipeline2.resolved.yaml' )->slurp;
my $expected_resolved = Load( $expected_resolved_yaml );

is_deeply( $resolved, $expected_resolved, 'The resolved pipeline file is as expected' ); 



###### Test step filter ######
$pipeline_dir = dir( qw(td pipeline4) );
$pipeline_output_dir = dir( $pipeline_dir, qw(output) );
# parse first
my $parser = App::Pipeline::Lite2::Parser->new( pipeline_dir => $pipeline_dir, output_dir => $pipeline_output_dir, append_err_str => 0,prepend_cwd_str => 0);
$parser->preparse( pipeline_file => $parser->pipeline_file,  
                   yaml_outfile => $parser->pipeline_preparse_file );
$parser->parse( yaml_infile  => $parser->pipeline_preparse_file, 
                yaml_outfile => $parser->pipeline_parse_file);

my $App_Pipeline_Lite2_Resolver_Step_Filter = App::Pipeline::Lite2::Resolver->new(
    pipeline_dir => $pipeline_dir,
    run_id => 1,
    step_filter_str => '2-4',
    once_condition_filter => 0,
    use_relative_paths => 1,
    output_dir => $pipeline_output_dir    
);
$yaml_in  =  $App_Pipeline_Lite2_Resolver_Step_Filter->pipeline_parse_file;
$yaml_out =  $App_Pipeline_Lite2_Resolver_Step_Filter->pipeline_resolved_file;

$App_Pipeline_Lite2_Resolver_Step_Filter->current_run_num(1);
$App_Pipeline_Lite2_Resolver_Step_Filter->resolve( yaml_infile => $yaml_in, yaml_outfile => $yaml_out );
my $resolved_yaml = $yaml_out->slurp;
my $resolved = Load( $resolved_yaml );
my $expected_resolved_stepfiltered_yaml = file($expected_dir, 'pipeline4.resolved.stepfiltered.yaml' )->slurp;
my $expected_resolved_stepfiltered = Load( $expected_resolved_stepfiltered_yaml );
is_deeply( $resolved, $expected_resolved_stepfiltered, 'The resolved step filtered pipeline file is as expected' ); 

##### Test job Filter ####
$pipeline_dir = dir( qw(td pipeline5) );
$pipeline_output_dir = dir( $pipeline_dir, qw(output) );
my $parser = App::Pipeline::Lite2::Parser->new( pipeline_dir => $pipeline_dir, append_err_str => 0,prepend_cwd_str => 0);
$parser->preparse( pipeline_file => $parser->pipeline_file,  
                   yaml_outfile => $parser->pipeline_preparse_file );
$parser->parse( yaml_infile  => $parser->pipeline_preparse_file, 
                yaml_outfile => $parser->pipeline_parse_file);
my $App_Pipeline_Lite2_Resolver_Job_Filter = App::Pipeline::Lite2::Resolver->new(
    pipeline_dir => $pipeline_dir,
    run_id => 1,
    job_filter_str => '1',
    once_condition_filter => 0,
    use_relative_paths => 1,
    output_dir => $pipeline_output_dir
);
$yaml_in  =  $App_Pipeline_Lite2_Resolver_Job_Filter->pipeline_parse_file;
$yaml_out =  $App_Pipeline_Lite2_Resolver_Job_Filter->pipeline_resolved_file;
#warn $App_Pipeline_Lite2_Resolver_Job_Filter;
$App_Pipeline_Lite2_Resolver_Job_Filter->current_run_num(1);
$App_Pipeline_Lite2_Resolver_Job_Filter->resolve( yaml_infile => $yaml_in, yaml_outfile => $yaml_out );
my $resolved_yaml = $yaml_out->slurp;
my $resolved = Load( $resolved_yaml );
my $expected_resolved_jobfiltered_yaml = file($expected_dir, 'pipeline5.resolved.jobfiltered.yaml' )->slurp;
my $expected_resolved_jobfiltered = Load( $expected_resolved_jobfiltered_yaml );
is_deeply( $resolved, $expected_resolved_jobfiltered, 'The resolved job filtered pipeline file is as expected' ); 


#### Test Once Condition Filter #####
$pipeline_dir = dir( qw(td pipeline6) );
$pipeline_output_dir = dir( $pipeline_dir, qw(output) );

my $parser = App::Pipeline::Lite2::Parser->new( pipeline_dir => $pipeline_dir, append_err_str => 0,prepend_cwd_str => 0);
$parser->preparse( pipeline_file => $parser->pipeline_file,  
                   yaml_outfile => $parser->pipeline_preparse_file );
$parser->parse( yaml_infile  => $parser->pipeline_preparse_file, 
                yaml_outfile => $parser->pipeline_parse_file);
my $App_Pipeline_Lite2_Resolver_Once_Filter = App::Pipeline::Lite2::Resolver->new(
    pipeline_dir => $pipeline_dir,
    run_id => 1,
    use_relative_paths => 1,
    output_dir => $pipeline_output_dir
);
$yaml_in  =  $App_Pipeline_Lite2_Resolver_Once_Filter->pipeline_parse_file;
$yaml_out =  $App_Pipeline_Lite2_Resolver_Once_Filter->pipeline_resolved_file;
$App_Pipeline_Lite2_Resolver_Once_Filter->current_run_num(1);
$App_Pipeline_Lite2_Resolver_Once_Filter->resolve( yaml_infile => $yaml_in, yaml_outfile => $yaml_out );
my $resolved_yaml = $yaml_out->slurp;
my $resolved = Load( $resolved_yaml );
my $expected_resolved_oncefiltered_yaml = file($expected_dir, 'pipeline6.resolved.oncefiltered.yaml' )->slurp;
my $expected_resolved_oncefiltered = Load( $expected_resolved_oncefiltered_yaml );
is_deeply( $resolved, $expected_resolved_oncefiltered, 'The resolved once condition filtered pipeline file is as expected' ); 


### Test resolution of pipeline with placeholders in output line ###
$pipeline_dir = dir( qw(td pipeline8) );
my $parser = App::Pipeline::Lite2::Parser->new( pipeline_dir => $pipeline_dir, append_err_str => 0,prepend_cwd_str => 0);
$parser->preparse( pipeline_file => $parser->pipeline_file,  
                   yaml_outfile => $parser->pipeline_preparse_file );
$parser->parse( yaml_infile  => $parser->pipeline_preparse_file, 
                yaml_outfile => $parser->pipeline_parse_file);
my $App_Pipeline_Lite2_Resolver_Once_Filter = App::Pipeline::Lite2::Resolver->new(
    pipeline_dir => $pipeline_dir,
    run_id => 1,
);
$yaml_in  =  $App_Pipeline_Lite2_Resolver_Once_Filter->pipeline_parse_file;
$yaml_out =  $App_Pipeline_Lite2_Resolver_Once_Filter->pipeline_resolved_file;
$App_Pipeline_Lite2_Resolver_Once_Filter->current_run_num(1);
$App_Pipeline_Lite2_Resolver_Once_Filter->resolve( yaml_infile => $yaml_in, yaml_outfile => $yaml_out );
my $resolved_yaml = $yaml_out->slurp;
my $resolved = Load( $resolved_yaml );
print Dumper $resolved;
#my $expected_resolved_oncefiltered_yaml = file($expected_dir, 'pipeline8.resolved.outputplaceholder.yaml' )->slurp;
#my $expected_resolved_oncefiltered = Load( $expected_resolved_oncefiltered_yaml );
#is_deeply( $resolved, $expected_resolved_oncefiltered, 'The resolved once condition filtered pipeline file is as expected' ); 
=cut 






