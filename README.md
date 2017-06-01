[![Build Status](https://travis-ci.org/zoffixznet/perl6-Proc-Q.svg)](https://travis-ci.org/zoffixznet/perl6-Proc-Q)

# NAME

Proc::Q - Benchmark some code

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

# EXPORTED SUBROUTINES

## `proc-q`

Defined as:

```perl6
    sub proc-q (
        +@commands where .so && .all ~~ List & .so,

               :@tags where .elems == @commands   && .all ~~ Cool = @commands,
               :@in   where .elems == @commands|0 && .all ~~ Cool,
        UInt   :$timeout,
        Int:D  :$batch = 8,
        Bool:D :$out   = True,
        Bool:D :$err   = True,
        Bool:D :$merge where .not | .so & $out & $err = False,

        --> Supply:D
    )
```

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
