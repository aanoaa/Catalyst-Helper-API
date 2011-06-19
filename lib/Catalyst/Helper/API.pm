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
    $self->mk_model($helper, @args);
    $self->mk_api($helper, @args);
    $self->mk_conf($helper, @args);
}

sub mk_traits {
    my($self, $helper, @args) = @_;

    my $base = $helper->{base};
    my $app = $helper->{var}{namespace};
    $app =~ s/::/\//g;
    $helper->mk_dir(File::Spec->catfile($base, "lib/$app/Trait"));

    $helper->mk_dir(File::Spec->catfile($base, "conf")); # conf
    $helper->mk_dir(File::Spec->catfile($base, "logs"));
    my $conf = File::Spec->catfile($base, "conf", 'log4perl.conf');
    $conf .= '.new' if -e $conf;
    $helper->render_file('log4perl', $conf, $helper->{var});

    for my $trait (qw/trait_WithAPI trait_WithDBIC trait_Log/) {
        my $name = $trait;
        $name =~ s/^trait_//;
        my $pm = File::Spec->catfile($base, "lib/$app/Trait", "$name.pm");
        $helper->render_file($trait, $pm, $helper->{var});
    }
}

sub mk_model {
    my($self, $helper, @args) = @_;

    my $base = $helper->{base};
    my $app = $helper->{app};
    $app =~ s/::/\//g;

    my $pm = File::Spec->catfile($base, "lib/$app/Model", "API.pm");
    $helper->mk_dir(File::Spec->catfile($base, "lib/$app/Model"));
    $helper->render_file('model_api', $pm, $helper->{var});
}

sub mk_api {
    my($self, $helper, @args) = @_;

    my $base = $helper->{base};
    my $app = $helper->{var}{namespace};
    $app =~ s/::/\//g;

    my $pm = File::Spec->catfile($base, "lib/$app", "API.pm");
    $helper->mk_dir(File::Spec->catfile($base, "lib/$app"));
    $helper->render_file('api', $pm, $helper->{var});

    # TODO api layout
    $helper->mk_dir(File::Spec->catfile($base, "lib/$app/API"));
    for my $api (@args) {
        $helper->{var}{api} = $api;
        my $pm = File::Spec->catfile($base, "lib/$app/API", "$api.pm");
        $helper->render_file('api_layout', $pm, $helper->{var});
    }
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

__model_api__
package [% app %]::Model::API;
# ABSTRACT: use a plain API class as a Catalyst model
use Moose;
use namespace::autoclean;
extends 'Catalyst::Model::Adaptor';

=head1 DESCRIPTION

L<Catalyst::Model::Adaptor> Model

=head1 SEE ALSO

L<[% app %]>, L<Catalyst::Model::Adaptor>

=cut

1;

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

=head1 DESCRIPTION

[% namespace %]::Schema class required

1;

__trait_Log__
package [% namespace %]::Trait::Log;
# ABSTRACT: Log Trait for [% namespace %]::API Role
use Moose::Role;
use namespace::autoclean;

has log => (
    is => 'ro',
    isa => 'Log::Log4perl::Logger',
    lazy_build => 1,
);

sub _build_log {
    my $self = shift;
    Log::Log4perl::init('conf/log4perl.conf');
    return Log::Log4perl->get_logger(__PACKAGE__);
}

no Moose::Role;

=head1 SYNOPSIS

    package [% namespace %]::API::Something;
    use Moose;
    with '[% namespace %]::Trait::Log';
    sub foo {
        my ($self) = shift;
        $self->log->debug('message');
    }

=head1 DESCRIPTION

Using Log4perl instance without Catalyst Context

=cut

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

__api_layout__
package [% namespace %]::API::[% api %];
# ABSTRACT: [% namespace %]::API::[% api %]
use utf8;
use Moose;
use 5.012;
use namespace::autoclean;

with qw/[% namespace %]::API::WithDBIC [% namespace %]::Trait::Log/;

sub wtf {
    my ($self, $arg) = @_;
    # your stuff here
    return 'World Taekwondo Federation';
}

__PACKAGE__->meta->make_immutable;

=head1 SYNOPSIS

    $c->model('API')->find('[% api %]')->foo('wtf');  ## 'World Taekwondo Federation'

=head1 DESCRIPTION

[% api %] description here

=cut

1;

__log4perl__
[% TAGS [- -] -%]
#log4perl.logger = DEBUG, A1, MAILER, Screen
log4perl.logger = DEBUG, A1, Screen
log4perl.appender.A1 = Log::Log4perl::Appender::File
log4perl.appender.A1.TZ = KST
log4perl.appender.A1.layout = Log::Log4perl::Layout::PatternLayout
log4perl.appender.A1.layout.ConversionPattern = [%d] [- app -] [%p] %m%n
log4perl.appender.A1.utf8 = 1
log4perl.appender.A1.filename = logs/debug.log

log4perl.appender.MAILER = Log::Dispatch::Email::MailSend
log4perl.appender.MAILER.to = ** YOUR EMAIL **
log4perl.appender.MAILER.subject = [- app -] error mail
log4perl.appender.MAILER.layout  = Log::Log4perl::Layout::PatternLayout
log4perl.appender.MAILER.layout.ConversionPattern = %d{yyyy-MM-dd HH:mm:ss} %F(%L) %M [%p] %m %n
log4perl.appender.MAILER.Threshold = ERROR

log4perl.appender.Screen = Log::Log4perl::Appender::Screen
log4perl.appender.Screen.layout = Log::Log4perl::Layout::PatternLayout
log4perl.appender.Screen.layout.ConversionPattern = %d %m %n
