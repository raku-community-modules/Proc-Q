use lib <lib>;
use Test;
use Proc::Q;

plan 5;

my @commands = <foo bar ber meow moo>;
my $sup = proc-q @commands.map({(
    $*EXECUTABLE, '-e',
    'say "\qq[$_]" ~ $*IN.slurp; note "meows";'
    ~ ' sleep ' ~ $++
    ~ '; exit ' ~ $++
)}),
:tags[@commands.map: 'tag-' ~ *], :in[@commands».uc], :timeout(2.8), :merge;

my @res; react whenever $sup { @res.push: $_ }

# is @res.all, Proc::Q::Res;
# is +@res, +@commands, 'number of items in result';

@res = @res».Capture».Hash.sort: *.<merged>;
.<merged> = .<merged>.lines.sort for @res;
my @exitcodes = @res.map: { .<exitcode>:delete }
# is @exitcodes, [0, 0, 1, 2, 4]; # RT#131479
@res.map: { .<killed>:delete } # RT#131479

is-deeply @res[3], {:err("meows\n"),
  :merged(("meowMEOW", "meows").Seq), :out("meowMEOW\n"), :tag("tag-meow")};

is-deeply @res[1], {:err("meows\n"),
  :merged(("fooFOO", "meows").Seq), :out("fooFOO\n"), :tag("tag-foo")};

is-deeply @res[2], {:err("meows\n"),
  :merged(("barBAR", "meows").Seq), :out("barBAR\n"), :tag("tag-bar")};

is-deeply @res[3], {:err("meows\n"),
  :merged(("berBER", "meows").Seq), :out("berBER\n"), :tag("tag-ber")};

is-deeply @res[4], {:err("meows\n"),
  :merged(("meows", "mooMOO").Seq), :out("mooMOO\n"), :tag("tag-moo")}






# plan 5;
# my @commands = <foo bar ber meow moo>;
# my $sup = proc-q @commands.map({(
#     $*EXECUTABLE, '-e',
#     'say "\qq[$_]" ~ $*IN.slurp; note "meows";'
#     ~ ' sleep ' ~ ($++ > 2 ?? $++ !! 1000)
#     ~ '; exit ' ~ $++
# )}),
# :tags[@commands.map: 'tag-' ~ *], :in[@commands».uc], :timeout(2.8), :merge;
#
# my @res; react whenever $sup { @res.push: $_ }

# is @res.all, Proc::Q::Res;
# is +@res, +@commands, 'number of items in result';

# @res = @res».Capture».Hash.sort;
# .<merged> = .<merged>.lines.sort for @res;
# my @exitcodes = sort @res.map: { .<exitcode>:delete }
# is @exitcodes, [0, 0, 1, 2, 4];
#
# is-deeply @res[0], {:err("meows\n"), :!killed,
#   :merged(("fooFOO", "meows").Seq), :out("fooFOO\n"), :tag("tag-foo")};
#
# is-deeply @res[1], {:err("meows\n"), :killed,
#   :merged(("meowMEOW", "meows").Seq), :out("meowMEOW\n"), :tag("tag-meow")};
#
# is-deeply @res[2], {:err("meows\n"), :!killed,
#   :merged(("barBAR", "meows").Seq), :out("barBAR\n"), :tag("tag-bar")};
#
# is-deeply @res[3], {:err("meows\n"), :!killed,
#   :merged(("berBER", "meows").Seq), :out("berBER\n"), :tag("tag-ber")};
#
# is-deeply @res[4], {:err("meows\n"), :killed,
#   :merged(("meows", "mooMOO").Seq), :out("mooMOO\n"), :tag("tag-moo")}
