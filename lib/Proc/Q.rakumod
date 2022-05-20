my class Proc::Q::Res {
    has Stringy $.out      is required;
    has Stringy $.err      is required;
    has Stringy $.merged   is required;
    has Int:D   $.exitcode is required;
    has Mu      $.tag      is required;
    has Bool:D  $.killed   is required;
}

my sub proc-q (
    +@commands where .so && .all ~~ List & .so,

            :@tags where .elems == @commands = @commands,
            :@in   where {
                .elems == @commands|0
                and all .map: {$_ ~~ Cool:D|Blob:D|Nil or $_ === Any}
            } = (Nil xx @commands).List,
    Numeric :$timeout where .DEFINITE.not || $_ > 0,
    UInt:D  :$batch   where .so = 8,
            :$out     where Bool:D|'bin' = True,
            :$err     where Bool:D|'bin' = True,
    Bool:D  :$merge   where .not | .so & (
              $out & $err & (
                  ($err eq 'bin' & $out eq 'bin')
                | ($err ne 'bin' & $out ne 'bin'))) = False,

    --> Channel:D
) is export {
    my $c = Channel.new;
    (start await Supply.from-list(@commands Z @tags Z @in).throttle: $batch,
      -> ($command, $tag, $in) {
          with Proc::Async.new: |$command, :w($in.defined) -> $proc {
              CATCH { default { .say } }
              my Stringy $out-res = $out eq 'bin' ?? Buf.new !! '' if $out;
              my Stringy $err-res = $err eq 'bin' ?? Buf.new !! '' if $err;
              my Stringy $mer-res = $out eq 'bin' ?? Buf.new !! '' if $merge;

              $out and $proc.stdout(:bin($out eq 'bin')).tap: $out-res ~= *;
              $err and $proc.stderr(:bin($err eq 'bin')).tap: $err-res ~= *;
              if $merge {
                  $proc.stdout(:bin($out eq 'bin')).tap: $mer-res ~= *;
                  $proc.stderr(:bin($err eq 'bin')).tap: $mer-res ~= *;
              }

              my Promise:D $prom   = $proc.start;
              my Bool:D    $killed = False;
              $timeout.DEFINITE and $proc.ready.then: {
                  Promise.in($timeout).then: {
                      $killed = True;
                      $proc.kill: SIGTERM;
                      Promise.in(1).then: {$prom or $proc.kill: SIGSEGV}
                  }
              }

              with $in {
                  try await $in ~~ Blob ?? $proc.write:  $in
                                        !! $proc.print: ~$in;
                  $proc.close-stdin;
              }

              my $proc-obj = await $prom;

              $c.send: Proc::Q::Res.new:
                :err($err-res), :out($out-res), :merged($mer-res),
                :$tag,          :$killed,
                :exitcode($proc-obj.exitcode);
          }
    }).then: { $c.close };
    $c
}

=begin pod

=head1 NAME

Proc::Q - Queue up and run a herd of Procs

=head1 SYNOPSIS

=begin code :lang<raku>

use Proc::Q;

# Run 26 procs; each receiving stuff on STDIN and putting stuff out
# to STDOUT, as well as sleeping for increasingly long periods of
# time. The timeout of 3 seconds will kill all the procs that sleep
# longer than that.

my @stuff = 'a'..'z';
my $proc-chan = proc-q
             @stuff.map({«perl6 -e "print '$_' ~ \$*IN.slurp; sleep $($++/5)"»}),
  tags    => @stuff.map('Letter ' ~ *),
  in      => @stuff.map(*.uc),
  timeout => 3;

react whenever $proc-chan {
    say "Got a result for {.tag}: STDOUT: {.out}"
        ~ (". Killed due to timeout" if .killed)
}

# OUTPUT:
# Got a result for Letter a: STDOUT: aA
# Got a result for Letter b: STDOUT: bB
# Got a result for Letter c: STDOUT: cC
# Got a result for Letter d: STDOUT: dD
# Got a result for Letter e: STDOUT: eE
# Got a result for Letter f: STDOUT: fF
# Got a result for Letter g: STDOUT: gG
# Got a result for Letter h: STDOUT: hH
# Got a result for Letter i: STDOUT: iI
# Got a result for Letter j: STDOUT: jJ
# Got a result for Letter k: STDOUT: kK
# Got a result for Letter l: STDOUT: lL
# Got a result for Letter m: STDOUT: mM
# Got a result for Letter n: STDOUT: nN
# Got a result for Letter o: STDOUT: oO. Killed due to timeout
# Got a result for Letter p: STDOUT: pP. Killed due to timeout
# Got a result for Letter s: STDOUT: sS. Killed due to timeout
# Got a result for Letter t: STDOUT: tT. Killed due to timeout
# Got a result for Letter v: STDOUT: vV. Killed due to timeout
# Got a result for Letter w: STDOUT: wW. Killed due to timeout
# Got a result for Letter q: STDOUT: qQ. Killed due to timeout
# Got a result for Letter r: STDOUT: rR. Killed due to timeout
# Got a result for Letter u: STDOUT: uU. Killed due to timeout
# Got a result for Letter x: STDOUT: xX. Killed due to timeout
# Got a result for Letter y: STDOUT: yY. Killed due to timeout
# Got a result for Letter z: STDOUT: zZ. Killed due to timeout

=end code

=head1 DESCRIPTION

B<Requires Rakudo 2017.06 or newer>.

Got a bunch of L<C<Procs>|https://docs.perl6.org/type/Proc> you want
to queue up and run, preferably with some timeout for Procs that get
stuck? Well, good news!

=head1 EXPORTED SUBROUTINES AND TYPES

=head2 proc-q

Defined as:

=begin code :lang<raku>

sub proc-q(
    +@commands where .so && .all ~~ List & .so,

            :@tags where .elems == @commands = @commands,
            :@in   where {
                .elems == @commands|0
                and all .map: {$_ ~~ Cool:D|Blob:D|Nil or $_ === Any}
            } = (Nil xx @commands).List,
    Numeric :$timeout where .DEFINITE.not || $_ > 0,
    UInt:D  :$batch   where .so = 8,
            :$out     where Bool:D|'bin' = True,
            :$err     where Bool:D|'bin' = True,
    Bool:D  :$merge   where .not | .so & (
              $out & $err & (
                  ($err eq 'bin' & $out eq 'bin')
                | ($err ne 'bin' & $out ne 'bin'))) = False,

    --> Channel:D
)

=end code

See SYNOPSIS for sample use.

Returns a L<C<Channel>|https://docs.raku.org/type/Channel> of C<Proc::Q::Res>
objects. Batches the C<@commands> in batches of C<$batch> and runs those via
in parallel, optionally feeding STDIN with corresponding data from
C<@in>, as well as capturing STDOUT/STDERR, and L<killing the
process|https://docs.raku.org/type/Proc::Async#method_kill> after
C<$timeout>, if specified.

Arguments are as follows:

=head3 +@commands

A list of lists, where each of inner lists is a list of arguments to
L<C<Proc::Async.new>|https://docs.raku.org/type/Proc::Async#method_new>. You
do not need to specify the C<:w> argument, and if you do, its value will be
ignored.

Must have at least one list of commands inside C<@commands>.

=head3 :@tags

To make it possible to match the input with the output, you can C<tag> each
of the commands in C<@commands> by specifying the value via C<@tags> argument
at the same index as the command is at. The given tag will be available via
C<.tag> method of the C<Proc::Q::Res> object responsible.

Any object can be used as a tag. If <:@tags> is provided, it must have the same
number of elements as C<+@commands> argument. If it's not provided, it defaults
to C<@commands>.

=head3 :@in

Optionally, you can send stuff to STDIN of your procs, by giving a C<Blob> or
C<Str> in C<:@in> arg at the same index as the the index of the command for that
proc in C<@commands>. If specified, the number of elements in C<@in> must be the
same as number of elements in C<@commands>. Specify undefined value to avoid
sending STDIN to a particular proc.

TIP: is your queue hanging for some reason? Ensure the procs you're running
arent's sitting and waiting for STDIN. Try passing an empty strings in C<:@in>.

=head3 :$batch

Takes a positive C<Int>. Defaults to C<8>. Specifies how many C<@commands>
to run at the same time.

=head3 :$timeout

By default is not specified.

Takes a positive C<Numeric> specifying the number of seconds after which
a proc should be killed, if it did not complete yet. Timer starts ticking once
the proc is L<C<.ready>|https://docs.raku.org/type/Proc::Async#method_ready>.
The process is killed with C<SIGTERM> signal and if after 1 second it's still
alive, it gets another kill with C<SIGSEGV>.

=head3 :$out

Defaults to C<True>.

If set to C<True> or string C<'bin'>, the routine will capture STDOUT from the
procs, and make it available in C<.out> method of C<Proc::Q::Res> object. If set
to string <'bin'>, the output will be captured in binary and C<.out> method will
contain a C<Blob> instead of C<Str>.

=head3 :$err

Same as C<:$out> except as applied to procs' STDERR.

=head3 :$merge

Defaults to C<False>.

If set to C<True>, both C<:$err> and C<:$out> must be set to C<True> or
both set to string C<'bin'>.

If set to C<True>, the C<.merged> method will contain the merged output of
STDOUT and STDERR (so it'll be a C<Str> or, if the C<:$out>/C<:$err> arei
set to C<'bin'>, a C<Blob>).

B<Note> that there's no order guarantee. Output from a proc sent to STDERR
after output to STDOUT, might end up I<before> STDOUT's data in C<.merged>
object.

=head2 Proc::Q::Res

Each of the item sent to the C<Channel> from C<proc-q> routine will be
a C<Proc::Q::Res> object (technically, it might also be an C<Exception> object
if something explodes while trying to launch and wait for a proc, but it's of
the "should never happen" variety; the `Exception` will be the reason why
stuff exploded).

While the C<@commands> to be executed will be batched in C<:$batch> items,
the order within batches is not guaranteed. Use C<:@tags> to match the
C<Proc::Q::Res> to the input commands.

The C<Proc::Q::Res> type contains information about the proc that was ran and
provides these methods:

=head3 .tag

The same object that was given as a tag via C<:@tags> argument (by default,
the command from C<@commands> that was executed). The purpose of the C<.tag>
is to match this C<Proc::Q::Res> object to the proc you ran.

=head3 .out

Contains a C<Stringy> with STDOUT of the proc if C<:$out> argument to C<proc-q>
is set to a true value.

=head3 .err

Contains a C<Stringy> with STDERR of the proc if C<:$err> argument to C<proc-q>
is set to a true value.

=head3 .merged

Contains a C<Stringy> with merged STDOUT and STDERR of the proc if C<:$merge>
argument to C<proc-q> is set to a true value. Note that even when C<:$merge>
is in use, the C<.out> and C<.err> methods will contain the separated streams.

=head3 .exitcode

Contains L<the exit code|https://docs.raku.org/type/Proc#method_exitcode> of
the executed proc.

=head3 .killed

A C<Bool:D> that is C<True> if this proc was killed due to the C<:$timeout>.
More precisely, this is an indication that the timeout expired and the kill
code started to run. It B<is> possible for a proc to successfully complete in this
small window opportunity between the attribute being set and the signal from
L<C<.kill>|https://docs.raku.org/type/Proc::Async#method_kill>
being received by the process.

=head1 AUTHOR

Zoffix Znet

=head1 COPYRIGHT AND LICENSE

Copyright 2017 - 2018 Zoffix Znet

Copyright 2019 - 2022 Raku Community

This library is free software; you can redistribute it and/or modify it under the Artistic License 2.0.

=end pod

# vim: expandtab shiftwidth=4
