use Test::More tests => 1;
use App::Pipeline::Lite4::Parser;
use Path::Tiny;
use Data::Dumper;

my $pipeline = App::Pipeline::Lite4::Parser->new( pipeline_dir => path( qw(td test-pipeline-5) ) );
my $pipeline_file = path(qw(td test-pipeline-5 test-pipeline-5.pipeline));

warn "\n", $pipeline_file->slurp;

my $step_hash = App::Pipeline::Lite4::Parser::parse_pipeline_to_step_hash( $pipeline_file );

warn Dumper $step_hash; 

my $step_struct = App::Pipeline::Lite4::Parser::pipeline_step_hash_to_step_struct( $step_hash );

warn Dumper $step_struct;

ok(1);