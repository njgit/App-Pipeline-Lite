use Modern::Perl;
use IO::All;
use Path::Tiny;

my $book_path = path("td/book.txt");
my $book;
if( ! $book_path->exists ) {
  $book < io('http://www.gutenberg.org/files/45124/45124-0.txt');
  say "downloaded book";
  path("td/book.txt")->spew($book);
}else{
  $book = path("td/book.txt")->slurp;
  say "book already downloaded prev";
}

my @book = split  /\012\015?|\015\012?/, $book;
my $num_lines = scalar @book;

my $fifth_lines = int($num_lines / 5);
print say "Number of lines $num_lines, fifth = $fifth_lines";

my $line_num = 0;
my @book_part;
my @datasource;
foreach my $line (@book){
  $line_num++;

  if ( $line_num % $fifth_lines  == 0 ){
      my $name = "book.$line_num";
      my $book_part_path =  path('td',$name);
      $book_part_path->spew( join "\n", @book_part);
      @book_part = ();
      push @datasource , [ $name, $book_part_path->stringify ];
  }  
  push @book_part, $line;
}

my $datasource_path = path('td/book.datasource');
my $datasource_fh = $datasource_path->openw;
my $header = join "\t", 'name', 'path' ;
say $datasource_fh $header ;

$datasource_fh = $datasource_path->opena;
foreach my $row (@datasource) {
    say $datasource_fh join "\t", @$row;
}
