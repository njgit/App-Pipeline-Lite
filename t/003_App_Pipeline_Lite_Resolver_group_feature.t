use Test::More tests => 1;
use App::Pipeline::Lite4::Resolver;
use App::Pipeline::Lite4::Parser;
use Path::Tiny;
use Data::Dumper;
use YAML::Any;

my $pipeline_dir = path( qw(td test-pipeline-5) );

### MAKE THE DATASOURCE
my @files = map {path('td',$_)} qw(book.1609 book.3218 book.4827 book.6436 book.8045);
my @type = qw(A A A B B);
my @kind = qw(1 2 2 1 2);
my $datasource = path('td/book.datasource');
my @lines;
push (@lines, join "\t", "name", "path", "type", "kind\n");
my $i = 0;
foreach my $file ( @files ){
    
   my $line = join "\t", $file->basename, $file->absolute->stringify, $type[$i], $kind[$i]."\n";
   push (@lines,$line);
   $i++;
}
$datasource->spew(@lines);
###

  
## NEED TO DO THIS BECAUSE RESOLVER NEEDS TO PICK UP ON THE PROCESSED YAML FILES IN THE PIPELINE DIR
my $parser = App::Pipeline::Lite4::Parser->new( pipeline_dir => path( qw(td test-pipeline-5) ) );
$parser->preparse(   $parser->pipeline_file,  
                     $parser->pipeline_preparse_file );
$parser->parse(  $parser->pipeline_preparse_file, 
                 $parser->pipeline_parse_file);
#####################################################################################################
#my $pipeline_output_dir = path( $pipeline_dir, qw(output) );
my $App_Pipeline_Lite_Resolver = App::Pipeline::Lite4::Resolver->new(
    pipeline_dir => $pipeline_dir,
    run_id => 1,
    once_condition_filter => 0,
    use_relative_paths => 1,
    datasource_file => 'td/book.datasource',
#    output_dir => $pipeline_output_dir
);
$App_Pipeline_Lite_Resolver->_resolve;


#this will be the last of the datasource entries added to the placeholder hash
warn "PLACEHOLDER HASH STRUCTURE";
warn Dumper $App_Pipeline_Lite_Resolver->placeholder_hash;

warn "RESOLVED STEP STRUCTURE";
warn Dumper $App_Pipeline_Lite_Resolver->pipeline_step_struct_resolved;

ok(1);