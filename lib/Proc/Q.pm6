use v6.d.PREVIEW;
use RakudoPrereq v2017.05.343.g.99421.d.4.ca,
  'Proc::Q module requires Rakudo v2017.06 or newer';
unit module Proc::Q;

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
) is export {
    supply (@commands Z @tags Z @in).batch($batch).map: -> $pack {
        my @results = $pack.map: -> ($command, $tag, $in) {
            start do with Proc::Async.new: |$command, :w($in.defined) -> $proc {
                my Cool $out-res = $out eq 'bin' ?? Buf.new !! '' if $out;
                my Cool $err-res = $err eq 'bin' ?? Buf.new !! '' if $err;
                my Cool $mer-res = $out eq 'bin' ?? Buf.new !! '' if $merge;

                $out and $proc.stdout(:bin($out eq 'bin')).tap: $out-res ~= *;
                $err and $proc.stderr(:bin($err eq 'bin')).tap: $err-res ~= *;
                if $merge {
                    $proc.stdout(:bin($out eq 'bin')).tap: $mer-res ~= *;
                    $proc.stderr(:bin($err eq 'bin')).tap: $mer-res ~= *;
                }

                my Promise:D $prom   = $proc.start;
                my Bool:D    $killed = False;
                $timeout.DEFINITE and Promise.in($timeout).then: {
                    await $proc.ready;
                    $killed = True;
                    $proc.kill: SIGTERM;
                    Promise.in(1).then: {$prom or $proc.kill: SIGSEGV}
                }

                with $in {
                    await $in ~~ Blob ?? $proc.write: $in !! $proc.print: $in;
                    $proc.close-stdin;
                }

                my $proc-obj = await $prom;
                class Res {
                    has Cool   $.out      is required;
                    has Cool   $.err      is required;
                    has Cool   $.merged   is required;
                    has Int:D  $.exitcode is required;
                    has Mu     $.tag      is required;
                    has Bool:D $.killed   is required;
                }.new: :err($err-res), :out($out-res), :merged($mer-res),
                       :$tag,          :$killed,
                       :exitcode($proc-obj.exitcode)
            }
        }

        while @results {
            await Promise.anyof: @results;
            my @ready = @results.grep: *.so;
            @results .= grep: none @ready;
            emit .status ~~ Kept ?? .result !! .cause for @ready;
        }
    }
}
