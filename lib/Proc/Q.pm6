unit module Proc::Q;

sub proc-q (
    +@commands where .so && .all ~~ List & .so,

           :@tags where .all ~~ Cool = @commands,
    UInt   :$timeout,
    Int:D  :$batch = 8,
    Bool:D :$out   = True,
    Bool:D :$err   = True,
    Bool:D :$merge = False,

    --> Supply:D
) is export {
    supply @commands.batch($batch).map: -> $ (*@commands) {
        my @results;
        @commands

        my @results = @modules.map: -> $module {
            start {
                my $proc = Proc::Async.new: :out, :err,
                    |<zef --serial --debug install>, $module;
                CATCH { default { say "DIED HERE! "; .Str.say; .backtrace.say } }
                my $out = ''; my $err = '';
                $proc.stdout.tap: $out ~ *;
                $proc.stderr.tap: $err ~ *;
                my $proc-prom = $proc.start;
                Promise.in(INSTALL_TIMEOUT).then: {
                    $proc-prom or try {
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
            } does ModuleNamer[$module]
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
