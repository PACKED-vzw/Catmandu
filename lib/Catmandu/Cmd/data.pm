package Catmandu::Cmd::data;

use Catmandu::Sane;

our $VERSION = '1.0303';

use parent 'Catmandu::Cmd';
use Catmandu;
use namespace::clean;

sub command_opt_spec {
    (
        ["from-store=s",    "", {default => Catmandu->default_store}],
        ["from-importer=s", ""],
        ["from-bag=s",      ""],
        ["count",           ""],
        ["into-exporter=s", ""],
        ["into-store=s",    "", {default => Catmandu->default_store}],
        ["into-bag=s",      ""],
        ["start=i",         ""],
        ["limit=i",         ""],
        ["total=i",         ""],
        ["cql-query|q=s",   ""],
        ["query=s",         ""],
        ["fix=s@",        "fix expression(s) or fix file(s)"],
        ["var=s%",        ""],
        ["preprocess|pp", ""],
        ["replace",       ""],
        ["verbose|v",     ""],
    );
}

sub command {
    my ($self, $opts, $args) = @_;

    my $from_opts = {};
    my $into_opts = {};
    for (my $i = 0; $i < @$args; $i++) {
        my $arg = $args->[$i];
        if (my ($for, $key) = $arg =~ /^--(from|into)-([\w\-]+)$/) {
            if (defined(my $val = $args->[++$i])) {
                $key =~ s/-/_/g;
                ($for eq 'from' ? $from_opts : $into_opts)->{$key} = $val;
            }
        }
    }

    my $from;
    my $into;

    if ($opts->from_bag) {
        $from = Catmandu->store($opts->from_store, $from_opts)
            ->bag($opts->from_bag);
    }
    else {
        $from = Catmandu->importer($opts->from_importer, $from_opts);
    }

    if ($opts->query || $opts->cql_query) {
        $self->usage_error("Bag isn't searchable")
            unless $from->can('searcher');
        $from = $from->searcher(
            cql_query => $opts->cql_query,
            query     => $opts->query,
            limit     => $opts->limit,
        );
    }
    elsif (defined $opts->limit) {
        $from = $from->take($opts->limit);
    }

    if ($opts->start || defined $opts->total) {
        $from = $from->slice($opts->start, $opts->total);
    }

    if ($opts->count) {
        return say $from->count;
    }

    if ($opts->into_bag) {
        $into = Catmandu->store($opts->into_store, $into_opts)
            ->bag($opts->into_bag);
    }
    else {
        $into = Catmandu->exporter($opts->into_exporter, $into_opts);
    }

    if ($opts->fix) {
        $from = $self->_build_fixer($opts)->fix($from);
    }

    if ($opts->replace && $into->can('delete_all')) {
        $into->delete_all;
    }

    if ($opts->verbose) {
        $from = $from->benchmark;
    }

    my $n = $into->add_many($from);
    $into->commit;

    if ($opts->verbose) {
        say STDERR $n == 1 ? "added 1 object" : "added $n objects";
        say STDERR "done";
    }
}

1;

__END__

=pod

=head1 NAME

Catmandu::Cmd::data - store, index, search, import, export or convert (deprecated)

=head1 DEPRECIATION NOTICE

This fix is deprecated, Please use these commands instead:

=over 4

=item L<Catmandu::Cmd::convert>

=item L<Catmandu::Cmd::copy>

=item L<Catmandu::Cmd::import>

=item L<Catmandu::Cmd::export>

=item L<Catmandu::Cmd::count>

=item L<Catmandu::Cmd::delete>

=back

=cut
