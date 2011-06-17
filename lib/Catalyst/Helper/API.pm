package Catalyst::Helper::API;

# ABSTRACT: a short description for Catalyst::Helper::API

use strict;

=head1 METHODS

=head2 mk_compclass

Make Component Class.

=cut

sub mk_compclass {
    my ( $self, $helper ) = @_;
    my $file = $helper->{file};
    $helper->render_file( 'compclass', $file );
}

=head2 mk_comptest

Makes test for Controller.

=cut

sub mk_comptest {
    my ( $self, $helper ) = @_;
    my $test = $helper->{'test'};
    $helper->render_file( 'comptest', $test );
}

=head1 SYNOPSIS

    script/create.pl view NAME Catalyst::Helper::API

=head1 DESCRIPTION

Helper for Catalyst::Helper::API Views.

=head1 SEE ALSO

L<Catalyst::Helper>

=cut

1;

# PodWeaver complaint 'literal string' about '__DATA__',but mk_XXX subs should have it.
__DATA__

__compclass__
package [% class %];

use strict;
use warnings;

use base 'Catalyst::View::TT';

__PACKAGE__->config(
    TEMPLATE_EXTENSION => '.tt',
    render_die => 1,
);

=head1 NAME

[% class %] - Catalyst::Helper::API View for [% app %]

=head1 DESCRIPTION

Catalyst::Helper::API View for [% app %].

=head1 SEE ALSO

L<[% app %]>

=head1 AUTHOR

[% author %]

=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

1;

__comptest__
what the test?
