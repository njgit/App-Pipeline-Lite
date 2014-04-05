package App::Pipeline::Lite4::Template::TinyMod;

# Load overhead: 40k

#use 5.00503;
use strict;

$Template::Tiny::VERSION = '1.12';

# Evaluatable expression
my $EXPR = qr/ [a-z_\-][\-\w.]* /xs;

# Opening [% tag including whitespace chomping rules
my $LEFT = qr/
	(?:
		(?: (?:^|\n) [ \t]* )? \[\%\-
		|
		\[\% \+?
	) \s*
/xs;

# Closing %] tag including whitespace chomping rules
my $RIGHT  = qr/
	\s* (?:
		\+? \%\]
		|
		\-\%\] (?: [ \t]* \n )?
	)
/xs;

sub new {
	bless { @_[1..$#_] }, $_[0];
}

sub _process {
	my ($self, $stash, $text) = @_;
    # Resolve expressions

	$text =~ s/
		$LEFT ( $EXPR ) $RIGHT
	/
		eval {
			$self->_expression($stash, $1)
			. '' # Force stringification
		}
	/gsex;
	return $text;
}


sub _expression {
	my $cursor = $_[1];
	
	my @path   = split /\./, $_[2];
	if( $path[0] eq 'jobs'){
	  @path = ( $path[0], $path[1], join('.', @path[2 .. $#path]  ) ); 
	}else {
      @path = ( $path[0], join('.', @path[1 .. $#path]  ) );
	}
	
	foreach ( @path ) {
		# Support for private keys
		return undef if substr($_, 0, 1) eq '_';

		# Split by data type
		my $type = ref $cursor;
		
		#if ( $type eq 'ARRAY' ) {
		#	return '' unless /^(?:0|[0-9]\d*)\z/;
		#	$cursor = $cursor->[$_];
		#} elsif ( $type eq 'HASH' ) {
		#	$cursor = $cursor->{$_};
		#} elsif ( $type ) {
		#	$cursor = $cursor->$_();
		#} else {
		#	return '';
		#}
		if ( $type eq 'HASH' ) {
			$cursor = $cursor->{$_};
	    }else {
		  return '';	
        }
		
	}
	return $cursor;
}