use v6.d.PREVIEW;

unit module Proc::Q;
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
) is export {
    supply @commands.batch($batch).map: -> $ (*@commands) {
        my @results = @commands.map: -> $command {
            start do with Proc::Async.new: |$command, :$out, :$err {
                class Proc::Q::Res {
                    has Str:D  $.err is required;
                    has Str:D  $.out is required;
                    has Str:D  $.tag is required;
                    has Str    $.merged;
                    has Bool:D $.killed =  False;
                }
                my $out-s = ''; my $err-s = ''; my $mer-s = '';
                $out and .stdout.tap: $out-s ~ *;
                $err and .stderr.tap: $err-s ~ *;
                if $merge {
                    .stdout.tap: $mer-s ~ *;
                    .stdout.tap: $mer-s ~ *;
                }
                my $prom = .start;
                $timeout.DEFINITE and Promise.in($timeout).then: {
                    $prom or try {
                        $out ~= 'FAILED! KILLING INSTALL FOR TAKING TOO LONG!';
                        say "KILLING install of $module for taking too long";
                        $proc.kill;
                        $proc.kill: SIGTERM;
                        $proc.kill: SIGSEGV
                    }
                }
                so try await $proc-prom;
                OUTPUT_DIR.add($module.subst: :g, /\W+/, '-').spurt:
                      "ERR: $err\n\n-----\n\n" ~ "OUT: $out\n";
                $out
            }
        }

        say "Started {+@results} Promises. Awaiting results";
        while @results {
            await Promise.anyof: @results;
            my @ready = @results.grep: *.so;
            @results .= grep: none @ready;
            for @ready {
                say .Module-Name ~ ': ', .status ~~ Kept
                    ?? <SUCCEEDED!  FAILED!>[.result.contains: 'FAILED']
                    !! "died with {.cause}";
            }
        }
    }
}
