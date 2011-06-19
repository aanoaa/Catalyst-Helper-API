package Catalyst::Helper::API;
# ABSTRACT: Helper to create API.pm and congifuration file

use strict;
use warnings;
use File::Spec;

sub mk_stuff {
    my($self, $helper, @args) = @_;

    my $base = $helper->{base}; # current directory
    my $app = $helper->{app};   # ex) Foo::Web

    $app =~ s/::www$//i;
    $app =~ s/::web$//ig;

    $helper->{var} = {
        app         => $helper->{app},
        apis        => \@args || [],
        namespace   => $app,
    };

    $self->mk_traits($helper, @args);
    $self->mk_api($helper, @args);
    $self->mk_conf($helper, @args);
}

sub mk_traits {
    my($self, $helper, @args) = @_;

    my $base = $helper->{base};
    my $app = $helper->{var}{namespace};
    $app =~ s/::/\//g;
    $helper->mk_dir(File::Spec->catfile($base, "lib/$app/Trait"));
    for my $trait (qw/trait_WithAPI trait_WithDBIC trait_Log/) {
        my $name = $trait;
        $name =~ s/^trait_//;
        my $pm = File::Spec->catfile($base, "lib/$app/Trait", "$name.pm");
        $helper->render_file($trait, $pm, $helper->{var});
    }
}

sub mk_api {
    my($self, $helper, @args) = @_;

    my $base = $helper->{base};
    my $app = $helper->{var}{namespace};
    $app =~ s/::/\//g;

    my $pm = File::Spec->catfile($base, "lib/$app", "API.pm");
    $helper->mk_dir(File::Spec->catfile($base, "lib/$app"));
    $helper->render_file('api', $pm, $helper->{var});
}

sub mk_conf {
    my($self, $helper, @args) = @_;

    $helper->render_file('conf', Catalyst::Utils::appprefix($helper->{app}) . '.conf.new', $helper->{var});
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

__trait_Log__
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

__trait_WithDBIC__
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

__trait_WithAPI__
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
            dsn                 ** DSN **           ## ex) dbi:mysql:test
            user                ** USERNAME **
            password            ** PASSWORD **
            RaiseError          1
            AutoCommit          1
            mysql_enable_utf8   1
            on_connect_do       SET NAMES utf8      ## shut the fuck up and using utf8
        </connect_info>
        # <opts>
        #     <Module>        # ARGS of [% namespace %]::API::Module
        #         arg1          this is arg1
        #         arg2          this is arg2
        #     </Module>
        # </opts>
    </args>
</Model>
