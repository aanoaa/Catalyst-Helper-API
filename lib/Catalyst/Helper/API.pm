package Catalyst::Helper::API;
# ABSTRACT: Helper to create API.pm and congifuration file

use strict;
use warnings;
use File::Spec;

sub mk_stuff {
    my($self, $helper, @args) = @_;

    # Trait/WithAPI.pm
    # Trait/WithDBIC.pm
    # Trait/Log.pm
    # API.pm
    # myapp.conf

    $self->mk_traits($helper, @args);
    $self->mk_api($helper, @args);
    $self->mk_conf($helper, @args);

}

sub mk_traits {
    my($self, $helper, @args) = @_;
    for my $trait (qw/trait_withapi trait_withdbic trait_log/) {
        # do something
    }
}

sub mk_api {
    my($self, $helper, @args) = @_;
    my $base = $helper->{base}; # 현재 디렉토리
    my $app = $helper->{app};   # ex) Foo::Web

    $app =~ s/::www$//i;
    $app =~ s/::web$//ig;
    $app =~ s/::/\//g;

    my $pm = File::Spec->catfile($base, "lib/$app", "API.pm");

    $app =~ s{/}{::}g;

    my $var = {
        app         => $helper->{app},
        apis        => \@args || [],
        namespace   => $app,
    };

    $helper->mk_dir(File::Spec->catfile($base, "lib/$app"));
    $helper->render_file('api', $pm, $var);
}

sub mk_conf {
    my($self, $helper, @args) = @_;

    my $conf = Catalyst::Utils::appprefix($helper->{app});
    $helper->render_file('conf', "$conf.conf", $var);

    # share 만들까? 필요없을 듯
    my $template_conf = File::Spec->catfile( $dist_dir, 'myapp.conf' );
    my $conf = Catalyst::Utils::appprefix($helper->{app}) . '.conf.new';
    my $content = slurp $template_conf;
    my $vars = {
        lower_name => lc $helper->{name},
        name => $helper->{name}
    };
    $helper->render_file_contents($content, $conf, $vars);
    print "** please add below lines to your app conf\n";
    print "# ==========================================\n";
    print slurp $conf;
    print "# ==========================================\n";
}

=head1 SYNOPSIS

    script/create.pl API

=head1 DESCRIPTION

Helper for Catalyst::Helper::API

=head1 SEE ALSO

L<Catalyst::Helper>

=cut

1;

__DATA__

__api__
package [% namespace %]::API;
# ABSTRACT: Auto require [% app %] APIs
use Moose;
use namespace::autoclean;
use [% namespace %]::Schema;
with qw/[% namespace %]::Trait::WithAPI [% namespace %]::Trait::WithDBIC [% namespace %]::Trait::Log/;

sub _build_schema {
    my $self = shift;
    return [% namespace %]::Schema->connect( $self->connect_info );
}

sub _build_apis {
    my $self = shift;
    my %apis;

    for my $module (qw/[% apis.join(' ') %]/) {
        my $class = __PACKAGE__ . "::$module";
        if (!Class::MOP::is_class_loaded($class)) {
            Class::MOP::load_class($class);
        }
        my $opt = $self->opts->{$module} || {};
        $apis{$module} = $class->new( schema => $self->schema, %{ $opt } );
    }

    return \%apis;
}

1;

__trait_log__
package [% namespace %]::Trait::WithAPI;
# ABSTRACT: Log Trait for [% namespace %]::API Role
use Moose::Role;
use namespace::autoclean;

has apis => (
    is => 'rw',
    isa => 'HashRef[Object]',
    lazy_build => 1,
);

has opts => (
    is => 'rw',
    isa => 'HashRef',
    default => sub { +{} }
);

sub find {
    my ($self, $key) = @_;
    my $api = $self->apis->{$key};
    if (!$api) {
        confess "API by key $key was not found for $self";
    }
    $api;
}

no Moose::Role;

1;

__trait_withdbic__
package [% namespace %]::Trait::WithDBIC;
# ABSTRACT: DBIC Trait for [% namespace %]::API Role
use Moose::Role;
use namespace::autoclean;

has schema => (
    is => 'ro',
    lazy_build => 1,
    handles => {
        txn_guard => 'txn_scope_guard',
    }
);

has connect_info => (
    is => 'ro',
    isa => 'HashRef',
);

has default_moniker => (
    is => 'ro',
    isa => 'Maybe[Str]',
    lazy_build => 1,
);

has resultset_constraints => (
    is => 'ro',
    isa => 'HashRef',
    predicate => 'has_resultset_constraints',
);

sub _build_resultset_constraints { return +{} }

sub resultset {
    my ($self, $moniker) = @_;

    my $schema = $self->schema();
    $moniker ||= $self->default_moniker;
    if (! $moniker) {
        confess blessed($self) . "->resultset() did not receive a moniker, nor does it have a default moniker";
    }

    my $rs = $schema->resultset($moniker);
    if ( $moniker eq $self->default_moniker && $self->has_resultset_constraints ) {
        return $rs->search( $self->resultset_constraints );
    } else {
        return $rs;
    }
}

no Moose::Role;

1;

__trait_withapi__
package [% namespace %]::Trait::WithAPI;
# ABSTRACT: API Trait for [% namespace %]::API Role
use Moose::Role;
use namespace::autoclean;

has apis => (
    is => 'rw',
    isa => 'HashRef[Object]',
    lazy_build => 1,
);

has opts => (
    is => 'rw',
    isa => 'HashRef',
    default => sub { +{} }
);

sub find {
    my ($self, $key) = @_;
    my $api = $self->apis->{$key};
    if (!$api) {
        confess "API by key $key was not found for $self";
    }
    $api;
}

no Moose::Role;

1;

__conf__
<Model API>
    class   [% namespace %]::API
    <args> # ARGS of Class Constructor
        <connect_info>
            dsn                 **DSN** # dbi:mysql:t_best
            user                **USERNAME**
            password            **PASSWORD**
            RaiseError          1
            AutoCommit          1
            mysql_enable_utf8   1
            on_connect_do       SET NAMES utf8
        </connect_info>
        # <opts>
        #     <System>        # ARGS of [% namespace %]::API::System
        #         key         value
        #         key2        another value
        #     </System>
        # </opts>
    </args>
</Model>
