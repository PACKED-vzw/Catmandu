package Catmandu::Fix::sort_field;

use Catmandu::Sane;
use Moo;
use List::MoreUtils;

with 'Catmandu::Fix::Base';

has path => (is => 'ro', required => 1);
has uniq => (is => 'ro', required => 1);
has reverse => (is => 'ro');
has numeric => (is => 'ro');

around BUILDARGS => sub {
    my ($orig, $class, $path, %options) = @_;
    my %args = (path => $path);
    for my $key (qw(uniq reverse numeric)) {
        $args{$key} = (defined $options{$key} && $options{$key}) ||
                      (defined $options{"-$key"} && $options{"-$key"});
    }
    $orig->($class, %args);
};

sub emit {
    my ($self, $fixer) = @_;
    my $path = $fixer->split_path($self->path);
    my $key = pop @$path;
    my $comparer = $self->numeric ? "<=>" : "cmp";

    $fixer->emit_walk_path($fixer->var, $path, sub {
        my $var = shift;
        $fixer->emit_get_key($var, $key, sub {
            my $var = shift;
            my $perl = "if (is_array_ref(${var})) {";

            if ($self->uniq) {
                $perl .= "${var} = [List::MoreUtils::uniq(\@{${var}})];";
            }

            if ($self->reverse) {
                $perl .= "${var} = [sort { \$b $comparer \$a } \@{${var}}];";
            } else {
                $perl .= "${var} = [sort { \$a $comparer \$b } \@{${var}}];";
            }

            $perl .= "}";
            $perl;
        });
    });

}

=head1 NAME

Catmandu::Fix::sort_field - sort the values of an array

=head1 SYNOPSIS

   # e.g. tags => ["foo", "bar","bar"]
   sort_field('tags'); # tags =>  ["bar","bar","foo"]
   sort_field('tags',-uniq=>1); # tags =>  ["bar","foo"]
   sort_field('tags',-uniq=>1,-reverse=>1); # tags =>  ["foo","bar"]
   # e.g. nums => [ 100, 1 , 10]
   sort_field('nums',-numeric=>1); # nums => [ 1, 10, 100]

=head1 SEE ALSO

L<Catmandu::Fix>

=cut

1;
