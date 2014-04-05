use Test::More tests => 3;
use App::Pipeline::Lite4::Base;

my $plite_base = App::Pipeline::Lite4::Base->new( pipeline_dir => 'td/pipeline1');
ok( $plite_base->pipeline_dir->is_absolute , "got absolute filename") ;

#to use relative paths must set like this - first set use_relative_paths, then set pipeline_dir (otherwise trigger files before use_relative_paths set) 
$plite_base = App::Pipeline::Lite4::Base->new( use_relative_paths => 1);
$plite_base->pipeline_dir('td/pipeline1');
ok( $plite_base->pipeline_dir->is_relative, "got relative filename" );
is($plite_base->pipeline_name, 'pipeline1');
1;