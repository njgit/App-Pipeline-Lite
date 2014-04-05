use Test::More tests => 1;
use App::Pipeline::Lite4::Parser;
use Path::Tiny;
use Data::Dumper;

my $pipeline = App::Pipeline::Lite4::Parser->new( pipeline_dir => path( qw(td test-pipeline-1) ) );
my $pipeline_file = path(qw(td test-pipeline-1 test-pipeline-1.pipeline));

warn "\n", 
     $pipeline_file->slurp;

my $step_hash = App::Pipeline::Lite4::Parser::parse_pipeline_to_step_hash( $pipeline_file );

warn Dumper $step_hash; 

my $step_struct = App::Pipeline::Lite4::Parser::pipeline_step_hash_to_step_struct( $step_hash );

warn Dumper $step_struct;

ok(1);

#$parser->preparse( pipeline_file => $pipeline_file,  
#                   yaml_outfile => $pipeline->pipeline_preparse_file );



#use Path::Class qw(dir file);
#use Data::Dumper;
#use YAML::Any;
#use File::Copy;

=cut
my $pipeline = App::Pipeline::Lite2::Parser->new( pipeline_dir => dir( qw(td pipeline2) ), append_err_str => 0, prepend_cwd_str => 0 );
my $pipeline_file = file(qw(td pipeline2 pipeline2.pipeline));
my $step_hash = App::Pipeline::Lite2::Parser::parse_pipeline_to_step_hash( file => $pipeline_file);

my $parser = App::Pipeline::Lite2::Parser->new( pipeline_dir => dir($pipeline_file));
 
$parser->preparse( pipeline_file => $pipeline_file,  
                   yaml_outfile => $pipeline->pipeline_preparse_file );

$parser->parse( yaml_infile  => $pipeline->pipeline_preparse_file, 
                yaml_outfile => $pipeline->pipeline_parse_file);

# ** NEED SOME FUNCTIONAL TESTS HERE **

# test the re-numbering
my $pipeline = App::Pipeline::Lite2::Parser->new( pipeline_dir => dir( qw(td pipeline7) ),  append_err_str => 0,prepend_cwd_str => 0  );
my $pipeline_dir = dir(qw(td pipeline7));
my $pipeline_file = file(qw(td pipeline7 pipeline7.pipeline));
my $parser = App::Pipeline::Lite2::Parser->new( pipeline_dir => dir($pipeline_dir),  append_err_str => 0, prepend_cwd_str => 0 );
 
$parser->preparse( pipeline_file => $pipeline_file,  
                   yaml_outfile => $pipeline->pipeline_preparse_file );

$parser->parse( yaml_infile  => $pipeline->pipeline_preparse_file, 
                yaml_outfile => $pipeline->pipeline_parse_file);

$parser->renum( preparse_yaml_file => $pipeline->pipeline_preparse_file, 
                 parse_yaml_file => $pipeline->pipeline_parse_file);                

copy("td/pipeline7/pipeline7.pipeline" , "td/pipeline7/pipeline7.pipeline.renum");
copy("td/pipeline7/pipeline7.pipeline.old", "td/pipeline7/pipeline7.pipeline");

my $renum = file("td/pipeline7/pipeline7.pipeline.renum")->slurp;
my $expected_renum = file("td/expected/pipeline7.pipeline.renum")->slurp;
is( $renum, $expected_renum );
=cut