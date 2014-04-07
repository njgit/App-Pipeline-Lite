package App::Pipeline::Lite4::Packer;
use Moo;
use App::FatPacker;
use Path::Tiny;
# thieve from Carton fatpacking (MIYAGAWA)

sub fatpack_plite {
    my $self = shift;
    my $dir = path(shift);
    my $file = $dir->child('plite');
    
    my $fatpacked = $self->do_fatpack($file);     
    my $executable = path($dir,'packed')->child('plite');
    warn "... Bundling $executable\n";   
    $executable->spew($fatpacked);
    chmod 0755, $executable;
}

sub do_fatpack {
    my ($self, $file) = @_;
    my $packer = App::FatPacker->new;
 
    my @modules = split /\r?\n/, $packer->trace(args => [$file]); #, use => $self->required_modules);
    @modules = grep { !/main.pm/ } @modules;
    @modules = grep { !/XS.pm/ } @modules;
    print join "\n", @modules, "\n"; 
    my @packlists = $packer->packlists_containing(\@modules);
    $packer->packlists_to_tree(Path::Tiny->new('fatlib')->absolute, \@packlists);
 
    my $fatpacked = do {
        local $SIG{__WARN__} = sub {};
        $packer->fatpack_file($file);
    };
 
    # HACK: File::Spec bundled into arch in < 5.16, but is loadable as pure-perl
    #use Config;
    #$fatpacked =~ s/\$fatpacked{"$Config{archname}\/(Cwd|File)/\$fatpacked{"$1/g;
    $fatpacked;
}
1;