use Test::More tests => 1;
use App::Pipeline::Lite4::Grapher;
use Path::Tiny;
use Data::Dumper;
use YAML::Any;

#my $expected_dir = dir( qw(td expected)  );
my $pipeline_dir = path( qw(td test-pipeline-5) );

my $App_Pipeline_Lite_Grapher = App::Pipeline::Lite4::Grapher->new(
    pipeline_dir => $pipeline_dir,
    run_id => 30,
);

my $yaml_in  =  $App_Pipeline_Lite_Grapher->pipeline_resolved_file;
my $yaml_out =  $App_Pipeline_Lite_Grapher->pipeline_graph_file;

$App_Pipeline_Lite_Grapher->add_dependents( $yaml_in, 
                                            $yaml_out );

my $dependents_added_pipeline_yaml = $yaml_out->slurp;
#my $dependents_added_pipeline = Load( $dependents_added_pipeline_yaml );

warn Dumper $dependents_added_pipeline_yaml;
ok(1);