package App::Pipeline::Lite4::Logger;
use Moo;
use MooX::late;
use Path::Tiny;
use Time::Piece;
use Devel::StackTrace;
has logfile => ( isa => 'Path::Tiny|Undef', is => 'rw' );
has system_logfile => ( isa => 'Path::Tiny|Undef', is => 'rw' );
sub log {
    my $self  = shift;
    my $level = shift;
    my $msg   = shift; 
    
    my $t = localtime;  
    my $trace = Devel::StackTrace->new();
    
    my $frame = $trace->frame(1);
    my $package = $frame->package;
    my $app_caller = "unknown";
    
    while ( my $frame = $trace->prev_frame() ) {
       if ( $frame->package =~ /Command\:\:(.+)/ ) {
          $app_caller = $1;
          last;
       }
    }
    
    my $log_msg = "[" . $level . "] " . "[ $app_caller -> $package ] " . " [ " . $t->strftime . " ] " . $msg;         
    my $append_log = $self->logfile->opena; #( $level =~ /sys/ ) ? $self->system_logfile->opena : $self->logfile->opena;
    print $append_log $log_msg, "\n";
}

sub debug {
   my $self = shift;
   my $msg  = shift;
   $self->log("debug",$msg) ;
}

sub info {
   my $self = shift;
   my $msg  = shift;
   $self->log("info",$msg) ;
}


1;