use strict;
use warnings;
package App::Pipeline::Lite4::Util ;
use Moo;
 
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

sub uniq {
  my %seen;
  return grep { !$seen{$_}++ } @_;
}

 
1;