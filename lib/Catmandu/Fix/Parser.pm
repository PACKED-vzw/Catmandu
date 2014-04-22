package Catmandu::Fix::Parser;

use Catmandu::Sane;
use Marpa::R2;
use Catmandu::Util qw(check_string read_file);
use Catmandu::Fix::Reject;
use Moo;

my $GRAMMAR = <<'GRAMMAR';
:default ::= action => ::array
:start ::= fixes
:discard ~ whitespace

fixes ::= expression*

expression ::= old_if     action => ::first
             | old_unless action => ::first
             | if         action => ::first
             | if_else    action => ::first
             | unless     action => ::first
             | select     action => ::first
             | reject     action => ::first
             | fix        action => ::first

old_if ::= old_if_condition fixes ('end()') bless => IfElse

old_unless ::= old_unless_condition fixes ('end()') bless => Unless

if ::= ('if') condition fixes ('end') bless => IfElse

if_else ::= ('if') condition fixes ('else') fixes ('end') bless => IfElse

unless ::= ('unless') condition fixes ('end') bless => Unless

select ::= ('select') condition bless => Select

reject ::= ('reject') condition bless => Reject

old_if_condition ::= old_if_name ('(') args (')') bless => OldCondition

old_unless_condition ::= old_unless_name ('(') args (')') bless => OldCondition

condition ::= name ('(') args (')') bless => Condition

fix ::= name ('(') args (')') bless => Fix

args ::= arg* separator => sep

arg ::= int         bless => Int
      | qq_string   bless => DoubleQuotedString
      | bare_string bless => BareString

old_if_name ~ 'if_' [a-z] name_rest

old_unless_name ~ 'unless_' [a-z] name_rest

name      ~ [a-z] name_rest
name_rest ~ [_\da-z]*

int ~ digits
    | '-' digits

digits ~ [\d]+

qq_string ~ '"' qq_chars '"'
qq_chars  ~ qq_char*
qq_char   ~ [^"] | '\"'

bare_string ~ [^\s,;:=>()"]+

whitespace ~ [\s]+

sep ~ [,;:]
    | '=>'
GRAMMAR

sub parse {
    my ($self, $source) = @_;

    check_string($source);

    if ($source !~ /\(/) {
        $source = read_file($source);
    }

    my $grammar = Marpa::R2::Scanless::G->new({
        bless_package  => __PACKAGE__,
        source => \$GRAMMAR,
    });
    my $recce = Marpa::R2::Scanless::R->new({grammar => $grammar});
    $recce->read(\$source);

    use Data::Dumper;
    my $parsed = ${$recce->value};
    die Dumper([map {$_->reify} @$parsed]);
}

sub Catmandu::Fix::Parser::IfElse::reify {
    my $cond       = $_[0]->[0]->reify;
    my $fixes      = $_[0]->[1];
    my $else_fixes = $_[0]->[2];
    push @{$cond->fixes}, map { $_->reify } @$fixes;
    push @{$cond->else_fixes}, map { $_->reify } @$else_fixes if $else_fixes;
    $cond;
}

sub Catmandu::Fix::Parser::Unless::reify {
    my $cond       = $_[0]->[0]->reify;
    my $else_fixes = $_[0]->[1];
    push @{$cond->else_fixes}, map { $_->reify } @$else_fixes;
    $cond;
}

sub Catmandu::Fix::Parser::Select::reify {
    my $cond = $_[0]->[0]->reify;
    push @{$cond->else_fixes}, Catmandu::Fix::Reject->new;
    $cond;
}

sub Catmandu::Fix::Parser::Reject::reify {
    my $cond = $_[0]->[0]->reify;
    push @{$cond->fixes}, Catmandu::Fix::Reject->new;
    $cond;
}

sub Catmandu::Fix::Parser::Fix::reify {
    my $name = $_[0]->[0];
    my $args = $_[0]->[1];
    Catmandu::Util::require_package($name, 'Catmandu::Fix')
        ->new(map { $_->reify } @$args);
}

sub Catmandu::Fix::Parser::Condition::reify {
    my $name = $_[0]->[0];
    my $args = $_[0]->[1];
    Catmandu::Util::require_package($name, 'Catmandu::Fix::Condition')
        ->new(map { $_->reify } @$args);
}

sub Catmandu::Fix::Parser::OldCondition::reify {
    my $name = $_[0]->[0];
    my $args = $_[0]->[1];
    $name =~ s/^(?:if|unless)_//;
    Catmandu::Util::require_package($name, 'Catmandu::Fix::Condition')
        ->new(map { $_->reify } @$args);
}

sub Catmandu::Fix::Parser::DoubleQuotedString::reify {
    my $str = $_[0]->[0];

    $str = substr($str, 1, length($str) - 2);

    if (index($str, '\\') != -1) {
        $str =~ s/\\u([0-9A-Fa-f]{4})/chr(hex($1))/egxms;
        $str =~ s/\\n/\n/gxms;
        $str =~ s/\\r/\r/gxms;
        $str =~ s/\\b/\b/gxms;
        $str =~ s/\\f/\f/gxms;
        $str =~ s/\\t/\t/gxms;
        $str =~ s/\\\\/\\/gxms;
        $str =~ s{\\/}{/}gxms;
        $str =~ s{\\"}{"}gxms;
    }

    $str;
}

sub Catmandu::Fix::Parser::BareString::reify {
    $_[0]->[0];
}

sub Catmandu::Fix::Parser::Int::reify {
    int($_[0]->[0]);
}


#sub _parser {
    #state $parser = do {
        #use Regexp::Grammars;
        #qr/
            #<expr>

            #<rule: expr>         <if_block>
                                 #(?{ my $fix = $MATCH{if_block}{fix};
                                     #my $instance = _build_fix_instance($fix->{name}, 'Catmandu::Fix::Condition', $fix->{args} || []);
                                     #if ($MATCH{if_block}{expr}) {
                                         #push @{$instance->fixes},
                                            #map { $_->{instance} } @{$MATCH{if_block}{expr}};
                                     #}
                                     #if ($MATCH{if_block}{else_block} && $MATCH{if_block}{else_block}{expr}) {
                                         #push @{$instance->else_fixes},
                                            #map { $_->{instance} } @{$MATCH{if_block}{else_block}{expr}};
                                     #}
                                     #$MATCH{instance} = $instance;
                                 #})
                                 #|
                                 #<unless_block>
                                 #(?{ my $fix = $MATCH{unless_block}{fix};
                                     #my $instance = _build_fix_instance($fix->{name}, 'Catmandu::Fix::Condition', $fix->{args} || []);
                                     #if ($MATCH{unless_block}{expr}) {
                                         #push @{$instance->else_fixes},
                                            #map { $_->{instance} } @{$MATCH{unless_block}{expr}};
                                     #}
                                     #$MATCH{instance} = $instance;
                                 #})
                                 #|
                                 #<select>
                                 #(?{ my $fix = $MATCH{select}{fix};
                                     #my $instance = _build_fix_instance($fix->{name}, 'Catmandu::Fix::Condition', $fix->{args} || []);
                                     #push @{$instance->else_fixes}, Catmandu::Fix::Filter->new;
                                     #$MATCH{instance} = $instance;
                                 #})
                                 #|
                                 #<reject>
                                 #(?{ my $fix = $MATCH{reject}{fix};
                                     #my $instance = _build_fix_instance($fix->{name}, 'Catmandu::Fix::Condition', $fix->{args} || []);
                                     #push @{$instance->fixes}, Catmandu::Fix::Filter->new;
                                     #$MATCH{instance} = $instance;
                                 #})
                                 #|
                                 #<fix>
                                 #(?{ my $fix = $MATCH{fix};
                                     #my $instance = _build_fix_instance($fix->{name}, 'Catmandu::Fix', $fix->{args} || []);
                                     #$MATCH{instance} = $instance;
                                 #})

            #<rule: if_block>     if <fix> <[expr]>* <else_block>? end
                                 #|
                                 #if_<fix> <[expr]>* end \( \)

            #<rule: else_block>   else <[expr]>*

            #<rule: unless_block> unless <fix> <[expr]>* end
                                 #|
                                 #unless_<fix> <[expr]>* end \( \)

            #<rule: select>       select \( <fix> \)
            #<rule: reject>       reject \( <fix> \)

            #<rule: fix>          <name> \( \)
                                 #|
                                 #<name> \( <args> \)

            #<rule: args>         <[arg]>+ % <_sep>
                                 #<MATCH= (?{ $MATCH{arg} })>

            #<rule: arg>          <int>
                                 #|
                                 #<qq_string>
                                 #|
                                 #<q_string>
                                 #|
                                 #<string>
                                 #|
                                 #<fatal: Expected string or int>

            #<token: keyword>     if|unless|end|select|reject

            #<token: name>        <!keyword>
                                 #[a-z][a-z0-9_-]*

            #<token: int>         (-?\d+)
                                 #<MATCH= (?{ eval $CAPTURE })>

            #<token: qq_string>   "((?:[^\\"]|\\.)*)"
                                 #<MATCH= (?{ $CAPTURE })>

            #<token: q_string>    '((?:[^\\']|\\.)*)'
                                 #<MATCH= (?{ $CAPTURE })>

            #<token: string>      <!keyword>
                                 #[^\s,;:=>\(\)"']+

            #<token: _sep>        (?:\s|,|;|:|=>)+

            #<token: ws>          (?:<_sep>)*
        #/xms;
    #};
#}

#sub parse {
    #my ($self, $source) = @_;

    #check_string($source);

    #if ($source !~ /\(/) {
        #$source = read_file($source);
    #}

    #$source =~ $self->_parser || do {
        #my @err = @!;
        #Catmandu::BadArg->throw(join("\n", "can't parse fix(es):", @err));
    #};

    #if (my $expr = $/{expr}) {
        #if (is_array_ref($expr)) {
            #[ map { $_->{instance} } @$expr ];
        #} else {
            #[ $expr->{instance} ];
        #}
    #} else {
        #[];
    #}
#}

1;

