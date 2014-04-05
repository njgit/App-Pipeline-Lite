use strict;
use warnings;
package App::Pipeline::Lite4::Parser ;
use Moo;
use MooX::late;
use Ouch;
use Path::Tiny;
use YAML::Any;
use SHARYANTO::String::Util qw(trim rtrim);

extends 'App::Pipeline::Lite4::Base';

has append_err_str => ( isa => 'Bool' , is => 'rw', default => sub { 1;} );
has prepend_cwd_str => ( isa => 'Bool' , is => 'rw', default => sub { 1;} );

#has append => (isa => 'Str', is =>'rw', default=> sub {''} );
#has prepend =>  (isa => 'Str', is =>'rw', default=> sub {''} );

has append => (isa => 'Str|Undef', is =>'rw', lazy_build => 1 );
has prepend =>  (isa => 'Str|Undef', is =>'rw', lazy_build =>1  );

sub get_step_name { 
    #TYPE( :$str) 
   my $str = shift;
   my ($name) = $str =~ /^([\w\-]+)\./;
   return $name;
}

sub get_step_condition {
    my $str = shift;
   #TYPE: :$str 
  
   my ($condition) = $str =~ /^[\w\-]+\.(.+)/;
   return $condition;
}

sub _build_append {
    my $self = shift;
    my $append_str = $self->config->{_}->{append}; #check local config 
    
    # if does not exist, check system config    
    $append_str = $self->system_config->{_}->{append} 
                               unless defined( $append_str);
    $append_str = " " . $append_str . " "; #make sure there is a space between commands
    defined($append_str) ?  $append_str : undef;  
}

 sub _build_prepend {
    my $self = shift;
    my $prepend_str = $self->config->{_}->{prepend}; #check local config 
    
    # if does not exist, check system config    
    $prepend_str = $self->system_config->{_}->{prepend} 
                               unless defined( $prepend_str);
    $prepend_str = " " . $prepend_str . " " if defined($prepend_str); #make sure there is a space between commands
    defined($prepend_str) ?  $prepend_str : undef;  
}


sub preparse {
    my $self = shift;       
    my $pipeline_file = shift // $self->pipeline_file; # TYPE: Path::Class::File :$pipeline_file = $self->pipeline_file,   
    my $yaml_outfile = shift // $self->pipeline_preparse_file;     # TYPE: Path::Class::File :$yaml_outfile = $self->pipeline_preparse_file 
    # parse the current steps in the pipeline 
    my $step_hash = parse_pipeline_to_step_hash( $pipeline_file );       
    # append other stuff here first, and then err string
    # <---     
    $self->append_err_str_to_cmd( $step_hash  )
      if  ( $self->append_err_str );      
     # prepend other stuff here first, and then cwd string
     # <---   
    $self->prepend_str_to_cmd($step_hash, $self->prepend ) 
      if  ( defined $self->prepend);  
    $self->prepend_cwd_str_to_cmd($step_hash ) 
      if  ( $self->prepend_cwd_str);        
    $yaml_outfile->spew( Dump($step_hash) );
};

sub parse {
    # TYPE: Path::Class::File :$yaml_infile, 
    # TYPE: Path::Class::File :$yaml_outfile  
  my $self= shift;
  my $yaml_infile  =shift;
  my $yaml_outfile =shift;  
  my $step_hash_yaml = $yaml_infile->slurp;
  my $step_hash    = Load($step_hash_yaml); 
  my $step_struct  = pipeline_step_hash_to_step_struct( $step_hash );
  $yaml_outfile->spew( Dump($step_struct) );  
};

sub append_str_to_cmd {
  my $self = shift;
  # TYPE:  HashRef $step_hash
  my $step_hash = shift;  
  my $str = shift;
  my $append_str_func   = sub { my $step_name = shift // 'default'; return $str};
  # concat_to_cmd knows to provide step name to the coderef
  my $appended_step_hash = $self->concat_to_cmd($step_hash, $append_str_func, 'APPEND');
}

# yes this is a specific case of above - look to refactor
sub append_err_str_to_cmd {  
    my $self = shift;
    #TYPE: HashRef $step_hash 
    my $step_hash = shift;  
    my $append_str_func   =  sub { my $step_name = shift // 'default'; return " 2>[% $step_name.err %]" };
    # concat_to_cmd knows to provide step name to this coderef
    my $appended_step_hash = $self->concat_to_cmd($step_hash, $append_str_func, 'APPEND');  
}

sub prepend_str_to_cmd {
  my $self = shift;
  # TYPE:  HashRef $step_hash
  my $step_hash = shift;  
  my $str = shift;
  my $prepend_str_func   = sub { my $step_name = shift // 'default'; return $str};
  # concat_to_cmd knows to provide step name to the coderef
  my $prepended_step_hash = $self->concat_to_cmd($step_hash, $prepend_str_func, 'PREPEND');
}

# yes this is a specific case of above - look to refactor
sub prepend_cwd_str_to_cmd {
  my $self = shift;
  # TYPE:  HashRef $step_hash
  my $step_hash = shift;  
  my $prepend_str_func   = sub { my $step_name = shift // 'default'; return "cd [% $step_name %]; "};
  # concat_to_cmd knows to provide step name to the coderef
  my $prepended_step_hash = $self->concat_to_cmd($step_hash, $prepend_str_func, 'PREPEND');
}

# requires a coderef that returns a string, which can be used to 
# parameterise a step name
sub concat_to_cmd {
    my $self = shift;
    #TYPE: HashRef $step_hash 
    my $step_hash = shift;
    my $concat_string_code = shift;
    my $type_of_concat = shift; #APPEND or PREPEND
    foreach my $step ( keys %$step_hash) {
       my $step_name =  get_step_name( $step);
       $step_name = trim( $step_name ) ;
       $step_hash->{$step} = rtrim( $step_hash->{$step} );           
       my $concat_str = $concat_string_code->($step_name);
       my $step_cond = get_step_condition( $step);
       if( defined($step_cond) ){
           if($step_cond eq 'once'){              
               $step_hash->{$step} .= $concat_str if $type_of_concat eq 'APPEND';
               $step_hash->{$step}  = $concat_str . $step_hash->{$step} if $type_of_concat eq 'PREPEND' ;                             
           }
       } else {
               $step_hash->{$step} .= $concat_str if $type_of_concat eq 'APPEND';
               $step_hash->{$step} =  $concat_str . $step_hash->{$step} if $type_of_concat eq 'PREPEND' ;
       }
   } 
   return $step_hash;
}

=func parse_pipeline_file_to_step_hash
  A step hash has a key such as "1." and value "some_cmd -h MOREOPTIONS ARGS ..."
=cut
sub parse_pipeline_to_step_hash   {
    # TYPE:  Path::Tiny $file
    my $file = shift;
    # Each Step Starts with X. or X.output and then a space, where X is the step number
    # Can be multiline but cannot start with X. on a line
    my @pipeline_file_contents = $file->lines;
    my %stephash;
    my $stepname;
    foreach my $line (@pipeline_file_contents) {  
       
       if ( $line =~ /^#/){ next; }  
       my $C = qr{^[\w\-]+\.};
       my $D = qr{^[\w\-]+\.output};
       my $E = qr{^[\w\-]+\.once};
       my $F = qr{^[\w\-]+\.mem};       
       my $G = qr{^[\w\-]+\.after};
       my $H = qr{^[\w\-]+\.queue};

       # #my $G = qr{^[0-9]+\.skip_if_exists}
       # #my $E = qr{^[0-9]+\.no_err};
       
       my $I = qr{\s(.+)};
       my $rg = qr{        
           ($C|$D|$E|$F|$G|$H)$I      
       }x;
       
        if( $line =~ $rg) {          
            $stepname = $1;            
            my $steptext = $2;
            $stephash{$stepname} = $steptext;
        }else{
            $stephash{$stepname} .= $line; 
        }    
    }
    return {%stephash};  
}

#takes step hash and parses it to more processed structure
sub pipeline_step_hash_to_step_struct {
    #   TYPE: Path::Tiny :$yamlfile ) {
    my $step_hash = shift;
    my %step_struct;
    foreach my $step ( keys %$step_hash ){  
            
           my $step_name = get_step_name( $step);
           my $step_condition = get_step_condition( $step);
              
           if( !defined($step_condition) ) {
             $step_struct{$step_name}->{cmd} = $step_hash->{$step};
             $step_struct{$step_name}->{condition} = undef; # change to 'none'?
           } 
                      
           elsif( $step_condition eq 'output' ) {
               my @files = $step_hash->{$step} =~ /(\[\%.+?\%\]\S+|\S+)/g; #my @files = split(/\s/, $step_hash->{$step}); 
               $step_struct{$step_name}->{outputfiles} = \@files; #$step_hash->{$step};
           }
                      
           elsif( $step_condition eq 'once' ) {
             $step_struct{$step_name}->{cmd} = $step_hash->{$step};
             $step_struct{$step_name}->{condition} = 'once';
           }
           
           elsif ( $step_condition eq 'mem' ) { 
             $step_struct{$step_name}->{mem} = trim( $step_hash->{$step} );
           }
                  
           elsif ( $step_condition eq 'after' ) { 
             my @after = split(/\s/, $step_hash->{$step}); 
             $step_struct{$step_name}->{after} = \@after ;
           }
           
           elsif ( $step_condition eq 'queue' ) { 
             $step_struct{$step_name}->{queue} =trim( $step_hash->{$step} );
           }
           
           # get placeholders
           if( ! exists( $step_struct{$step_name}->{placeholders} ) ){$step_struct{$step_name}->{placeholders} = undef;}#initialise to undef
           if( ( ! defined $step_condition) or ($step_condition eq 'once') or ($step_condition eq 'output')  ){
             #my (@placeholders) = ( $step_hash->{$step} =~ /\[\%\s+([a-z0-9\.]+)\s\%\]/g );
             my (@placeholders) = ( $step_hash->{$step} =~ /\[\%\s+([\w\-\.]+)\s+\%\]/g ); #\w is alphanumeric plus _, added more spaces at end. Consider /\[\%\s+([a-z0-9_][\w\.]+)\s+\%\]/g enforcing lower case start.
             if ( @placeholders >= 1){ 
                $step_struct{$step_name}->{placeholders} = \@placeholders;
             }; 
           }   

    }
    return \%step_struct;
}

1;
