use strict;
use warnings;
package App::Pipeline::Lite4::Util ;
use Moo;
use Term::UI;
use Term::ReadLine; 
use Path::Tiny;
use Time::Piece;
use Data::Dumper;
extends 'App::Pipeline::Lite4::Base';
 
use Ouch;

sub view_file_with_editor {
    my $self = shift; 
    my $filename = shift; # PARAMETER TYPE: ( Path::Tiny $filename ) 
    
    my $editor = $self->system_config->{_}->{editor} ; #check system config first     
    ouch 'App_Pipeline_Lite4_Error', "No pipeline editor set, try --editor EDITOR.  (e.g. --editor vim)" unless defined($editor);    
    my $cmd = qq{$editor $filename};
    
    eval {
      system($cmd);
    };
    
    if ( hug ) {
      ouch 'App_Pipeline_Lite4_Error', "Viewing the file with the editor '$editor' did not work. Perhaps set something different in system config.";    
    }
}

sub set_editor  {
    my $self = shift;
    my $editor = shift; # TYPE: ( Str $editor  )
    $self->system_config->{_}->{editor}  = $editor;
    $self->system_config->write($self->system_config_file);
    $self->system_logger->log( "info", "Set $editor as default editor");
}

sub ask_for_description {
  #( Num $run_num ) {
  my $self = shift;  
  my $term = Term::ReadLine->new('describe-run');
    
  my $print_me = <<PRINTME;
     
     *************
      Description
     -------------    
PRINTME
    
    my $bool = $term->ask_yn(
            prompt => "Do you want to describe this run?"            
            );
          
   if($bool) {
     my $desc = $term->get_reply(
            print_me => $print_me,
            prompt => "Enter description: ",
     ); 
   }  
}

sub append_description {
  my $self         = shift;  
  my $run_info     = shift // "";
  my $message      = shift // "";
  my $append_file  = $self->pipeline_submission_file;
  my $t = localtime;
  my $run_desc = join "\t", $t->datetime, $run_info, $message;
  $run_desc .= "\n";
  my $path = path($append_file)->append($run_desc); 
}

sub uniq {
  my %seen;
  return grep { !$seen{$_}++ } @_;
}

sub datasource_groupby {
  my $self = shift;
  my $datasource_table  =shift;
  my $groupby_field = shift;
  my %group_hash; 
  # create hash
  my $next = $datasource_table->iterator();
  my $i = 0;
  while( my $row = $next->() ){ 
    #warn Dumper $row;   
    push( @{ $group_hash{ $row->{$groupby_field} } }, $i );  
    $i++;
  }
  return \%group_hash; 
}
#the idea is to only offer a groupby one attribute, if more than one
#is required then the datasource should be given an extra column and
# the two column mergedin to a specific column
# the exception is for grouptransby which will work with two columns in general I think.
# for testing purposes we have this here.
sub datasource_groupby2 {
  my $self = shift;
  my $datasource_table  =shift;
  my $groupby_field1 = shift;
  my $groupby_field2 = shift;
  my %group_hash; 
  # create hash
  my $next = $datasource_table->iterator();
  my $i = 0;
  while( my $row = $next->() ){ 
    #warn Dumper $row;
    
    if( defined($groupby_field1) and defined( $groupby_field2 )){    
        push( @{ $group_hash{$row->{$groupby_field1} .'-' . $row->{$groupby_field2} } } , $i );  
    }elsif( defined($groupby_field1 ) ){
        push( @{ $group_hash{ $row->{$groupby_field1} } }, $i );   
    }else{
        ouch "App_Pipeline_Lite4_Error","No groupby fields to group by";
    }
      
    $i++;
  }
  return \%group_hash; 
}

sub datasource_groupby2_num_groups {
  my $self = shift;
  my @args = @_;
  #warn "DATASOURC ARGS ," , Dumper @args;
  my $groupby_hash = $self->datasource_groupby2(@args);
  return scalar keys %$groupby_hash;  
}

sub groupby_placeholder_regex_get_step {
  my $self       = shift;
  my $datasource = shift;
  my $groupby_fields  = shift;

  my $col_names = $datasource->{header};
  my $col_names_rgx_str = join "|", @$col_names;               
  my $groupby_placeholder_rgx_str = 'groupby\.('.$col_names_rgx_str . ')\.(' . $col_names_rgx_str . ')*\.*(.+)$';
  
}

1;