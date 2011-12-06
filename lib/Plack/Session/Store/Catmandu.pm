package Plack::Session::Store::Catmandu;

our $VERSION = '0.01';

use Catmandu::Sane;
use Catmandu;
use parent qw(Plack::Session::Store);

sub new {
    my ($class, %opts) = @_;
    my $store = $opts{store} || 'default';
    my $bag = $opts{bag} || 'sessions';
    bless {
        bag => Catmandu::store($store)->bag($bag),
    }, $class;
}

sub fetch {
    my ($self, $id) = @_;
    my $obj = $self->{bag}->get($id) || return;
    delete $obj->{_id};
    $obj;
}

sub store {
    my ($self, $id, $obj) = @_;
    $obj->{_id} = $id;
    $self->{bag}->add($obj);
    delete $obj->{_id};
    $obj;
}

sub remove {
    my ($self, $id) = @_;
    $self->{bag}->delete($id);
}

1;
