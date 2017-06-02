use v6.d.PREVIEW;

unit module Proc::Q;

sub proc-q (
    +@commands where .so && .all ~~ List & .so,

            :@tags where .elems == @commands   && .all ~~ Cool = @commands,
            :@in   where .elems == @commands|0 && .all ~~ Cool,
    Numeric :$timeout where .DEFINITE.not | $_ > 0,
    UInt:D  :$batch where .so = 8,
    Bool:D  :$out = True,
    Bool:D  :$err = True,
    Bool:D  :$merge where .not | .so & $out & $err = False,

    --> Supply:D
) is export {
    supply (@commands Z @tags Z @in).batch($batch).map: -> $pack {
        my @results = $pack.map: -> ($command, $tag, $in) {
            start do with Proc::Async.new: |$command, :w($in.so) -> $proc {
                my $out-res = ''; my $err-res = ''; my $mer-res = '';
                $out and $proc.stdout.tap: $out-res ~= *;
                $err and $proc.stderr.tap: $err-res ~= *;
                if $merge {
                    $proc.stdout.tap: $mer-res ~= *;
                    $proc.stderr.tap: $mer-res ~= *;
                }
                my $prom = $proc.start;
                if $in {
                    await $in ~~ Blob ?? $proc.write: $in !! $proc.print: $in;
                    $proc.close-stdin;
                }

                my $killed = False;
                $timeout.DEFINITE and Promise.in($timeout).then: {
                    $prom or try {
                        $killed = True;
                        say $proc.kill: SIGTERM;
                        Promise.in(½).then: $proc.kill: SIGSEGV;
                    }
                }
                my $proc-obj = await $prom;

                class Res {
                    has Str:D  $.err      is required;
                    has Str:D  $.out      is required;
                    has Str:D  $.merged   is required;
                    has Int:D  $.exitcode is required;
                    has Str:D  $.tag      is required;
                    has Bool:D $.killed   is required;
                }.new: :err($err-res), :out($out-res), :merged($mer-res),
                       :$tag,          :$killed,  :exitcode($proc-obj.exitcode);
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
