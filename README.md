[![Build Status](https://travis-ci.org/zoffixznet/perl6-Proc-Q.svg)](https://travis-ci.org/zoffixznet/perl6-Proc-Q)

# NAME

Proc::Q - Queue up and run a whole ton of Procs

# SYNOPSIS

```perl6
    use Proc::Q;

    my @modules = <Testo  Test::When  WWW  IRC::Client  Number::Denominate>;
    react whenever proc-q @modules.map: { «zef --debug --install "$_"» } {
        when .out.contains: 'FAILED' {
            say "When I ran {.tag}, the installation failed: " ~ .err
        }
        say "When I ran {.tag}, the installation succeeded!"
    }

    # OUTPUT:
    # When I ran zef --debug --install "Testo", the installation succeeded!
    # When I ran zef --debug --install "IRC::Client", the installation succeeded!
    # When I ran zef --debug --install "Test::When", the installation succeeded!
    # When I ran zef --debug --install "Number::Denominate", the installation succeeded!
    # When I ran zef --debug --install "WWW", the installation failed:
    #    blah blah blah
    #    <stderr output omited for this example>
```

# DESCRIPTION

Got a bunch of [Procs](https://docs.perl6.org/type/Proc) you want to queue up
and run, preferably with some timeout for Procs that get stuck? Well, good news!

# EXPORTED SUBROUTINES AND TYPES

## `proc-q`

Defined as:

```perl6
    sub proc-q (
        +@commands where .so && .all ~~ List & .so,

                :@tags where .elems == @commands = @commands,
                :@in   where {
                    .elems == @commands|0
                    and all .map: {$_ ~~ Cool:D|Nil or $_ === Any}
                },
        Numeric :$timeout where .DEFINITE.not | $_ > 0,
        UInt:D  :$batch where .so = 8,
                :$out = True where Bool:D|'bin',
                :$err = True where Bool:D|'bin',
        Bool:D  :$merge where .not | .so & (
                  $out & $err & (
                       $err eq 'bin' & $out eq 'bin'
                    | ($err ne 'bin' & $out ne 'bin'))) = False,

        --> Supply:D
    )
```

Returns a [`Supply`](https://docs.perl6.org/type/Supply) of `Proc::Q::Res`
objects. Batches the `@commands` in batches of `$batch` and runs those via
in parallel, optionally feeding STDIN with corresponding data from
`@in`, as well as capturing STDOUT/STDERR, and [killing the
process](https://docs.perl6.org/type/Proc::Async#method_kill) after
`$timeout`, if specified.

Arguments are as follows:

### `+@commands`

A list of lists, where each of inner lists is a list of arguments to
[`Proc::Async.new`](https://docs.perl6.org/type/Proc::Async#method_new). You
do not need to specify the `:w` argument, and if you do, its value will be
ignored.

Must have at least one list of commands inside `@commands`

## `:@tags`

To make it possible to match the input with the output, you can 'tag' each
of the commands in `@commands` by specifying the value via `@tags` argument
at the same index as the command is at. The given tag will be available via
`.tag` method of the `Proc::Q::Res` object responsible.
Any object can be used as a tag. If `:@tags` is provided, it must have the same
number of elements as `+@commands` argument. If it's not provided, it defaults
to `@commands`.

## `:@in`

Optionally, you can send stuff to STDIN of your procs, by giving a `Blob` or
`Str` in `:@in` arg at the same index as the the index of the command for that
proc in `@commands`. If specified, the number of elements in `@in` must be the
same as number of elements in `@commands`. Specify undefined value to avoid
sending STDIN to a particular proc.

## `:$batch`

Takes a positive `Int`. Defaults to `8`. Specifies how many `@commands`
to run at the same time. The routine will wait for each batch to complete,
either by procs finishing or being killed due to timeout (see `:$timeout` arg).
The value should probably be something around the number of cores on your box.

## `:$timeout`

By default is not specified.
Takes a positive `Numeric` specifying the number of seconds after which
a proc should be killed, if it did not complete yet. Note that the timer
starts ticking after [`Proc::Async.start`
](https://docs.perl6.org/type/Proc::Async#method_start) is called, not after
the process actually starts up. The process is killed with `SIGTERM` signal
and if after 1 second it's still alive, it gets another kill with `SIGSEGV`.

**NOTE:** another batch of procs **won't get started** until all procs in the
current batch complete so if you don't specify a `$:timeout`, a single hung proc
will hold everyone up.

## `:$out`

Defaults to `True`.
If set to `True` or string `'bin'`, the routine will capture STDOUT from the
procs, and make it available in `.out` method of `Proc::Q::Res` object. If set
to string `'bin'`, the output will be captured in binary and `.out` method will
contain a `Blob` instead of `Str`

## `:$err`

Same as `:$out` except as applied to procs' STDERR.

## `:$merge`

Defaults to `False`.
If set to `True`, both `:$err` and `:$out` must be set to `True` or both set to
string `'bin'`.
If set to `True`, the `.merged` method will contain the merged output of
STDOUT and STDERR (so it'll be a `Str` or, if the `:$out`/`:$err` are set to
`'bin'`, a `Blob`).

**Note** that there's no order guarantee. Output from a proc sent to STDERR
after output to STDOUT, might end up *before* STDOUT's data in `.merged` object.

## `Proc::Q::Res`

Each of the item emited to the `Supply` from `proc-q` routine will be
a `Proc::Q::Res` object (technically, it might also be an `Exception` object
if something explodes while trying to launch and wait for a proc, but it's of
the "should never happen" variety; the `Exception` will be the reason why
stuff exploded).

While the `@commands` to be executed will be batched in `:$batch` items, the
order within batches is not guaranteed. Use `:@tags` to match the
`Proc::Q::Res` to the input commands.

The `Proc::Q::Res` type contains information about the proc that was ran and
provides these methods:

### `.tag`

The same object that was given as a tag via `:@tags` argument (by default,
the command from `@commands` that was executed). The purpose of the `.tag`
is to match this `Proc::Q::Res` object to the proc you ran.

### `.out`

Contains a `Cool` with STDOUT of the proc if `:$out` argument to `proc-q` is
set to a true value.

### `.err`

Contains a `Cool` with STDERR of the proc if `:$err` argument to `proc-q` is
set to a true value.

### `.merged`

Contains a `Cool` with merged STDOUT and STDERR of the proc if `:$merge`
argument to `proc-q` is set to a true value. Note that even when `:$merge` is in
use, the `.out` and `.err` methods will contain the separated streams.

### `.exitcode`

                    has Int:D   $.exitcode is required;
                    has Mu      $.tag      is required;
                    has Bool:D  $.killed   is required;
                }.new: :err($err-res), :out($out-res), :merged($mer-res),
                       :$tag,          :$killed,
                       :exitcode($proc-obj.exitcode)

----

#### REPOSITORY

Fork this module on GitHub:
https://github.com/zoffixznet/perl6-Proc-Q

#### BUGS

To report bugs or request features, please use
https://github.com/zoffixznet/perl6-Proc-Q/issues

#### AUTHOR

Zoffix Znet (http://perl6.party/)

#### LICENSE

You can use and distribute this module under the terms of the
The Artistic License 2.0. See the `LICENSE` file included in this
distribution for complete details.

The `META6.json` file of this distribution may be distributed and modified
without restrictions or attribution.
