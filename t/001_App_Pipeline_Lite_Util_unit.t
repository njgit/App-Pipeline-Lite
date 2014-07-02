use Test::More tests => 1;
use App::Pipeline::Lite4::Util;
# data table
use Data::Table;
use Path::Tiny;
use Data::Dumper;

my $util = App::Pipeline::Lite4::Util->new;

my $datasource = path("td/book.datasource");
my $t = Data::Table::fromTSV( $datasource->stringify );

warn Dumper( App::Pipeline::Lite4::Util->datasource_groupby ($t,'type')  ); 
ok(1)