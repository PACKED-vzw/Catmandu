package Catmandu::IdGenerator;

=head1 NAME

Catmandu::IdGenerator - A base class for modules that needs to generate identifiers

=head1 SYNOPSIS

    package MyPackage;

    use Moo;

    with 'Catmandu::IdGenerator';

    sub generate {
       return int(rand(999999)) . "-" . time;
    }

    package main;

    my $x = MyPackage->new;

    for (1..100) {
       printf "id: %s\n" m $x->generate;
    }

=head1 SEE ALSO

L<Catmandu::IdGenerator::Mock> ,
L<Catmandu::IdGenerator::UUID>

=cut
use Catmandu::Sane;
use Moo::Role;
use namespace::clean;

requires 'generate';

1;