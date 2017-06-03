use lib <lib>;
use Testo;
use Proc::Q;

plan 1;

my %tags is BagHash;
my @stuff := Mu, Nil, Any, class Foo {}, class Bar {}.new,
    42, 'meow', <foo bar>;
my @l = 'a'..'z';
react whenever proc-q
    @l.map({
        $*EXECUTABLE, '-e',
        "say '$_' ~ \$*IN.slurp; note '$_'; sleep {2*($++/5).Int}; exit {$++}"
    }),
    :tags[@l.map: 'tag' ~ *]
{
    say "wtf?";
    %tags{item .tag}++;
}

is-eqv %tags, @stuff.BagHash, 'seen all the tags';
