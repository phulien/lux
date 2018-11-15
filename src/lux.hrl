%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% Copyright 2012-2018 Tail-f Systems AB
%%
%% See the file "LICENSE" for information on usage and redistribution
%% of this file, and for a DISCLAIMER OF ALL WARRANTIES.
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% Defines

-define(FF(Format, Args), io_lib:format(Format, Args)).
-define(b2l(B), binary_to_list(B)).
-define(l2b(L), iolist_to_binary(L)).
-define(i2b(I), integer_to_binary(I)).
-define(i2l(I), integer_to_list(I)).
-define(a2l(A), atom_to_list(A)).
-define(a2b(A), ?l2b(?a2l(A))).
-define(APPLICATION, lux).
-define(TAG_WIDTH, 20).
-define(TAG(Tag), lux_utils:tag_prefix(Tag, ?TAG_WIDTH)).
-define(dmore, 10).
-define(RE_COMPILE_OPTS, [{newline,anycrlf}, multiline]).
-define(RE_RUN_OPTS,     [{newline,anycrlf}, notempty]).
-define(fail_pattern_matched, "fail pattern matched ").
-define(success_pattern_matched, "success pattern matched ").
-define(loop_break_pattern_mismatch,
        "Loop ended without match of break pattern ").
-define(TIMER_THRESHOLD, 0.85).
-define(SUITE_SUMMARY_LOG, "lux_summary.log").
-define(SUITE_CONFIG_LOG, "lux_config.log").
-define(SUITE_RESULT_LOG, "lux_result.log").
-define(CASE_EVENT_LOG, ".event.log").
-define(CASE_CONFIG_LOG, ".config.log").
-define(CASE_EXTRA_LOGS, ".extra.logs").
-define(CASE_TAP_LOG, "lux.tap").

-define(DEFAULT_LOG, <<"unknown">>).
-define(DEFAULT_HOSTNAME, <<"no_host">>).
-define(DEFAULT_CONFIG_NAME, <<"no_config">>).
-define(DEFAULT_SUITE, <<"no_suite">>).
-define(DEFAULT_CASE, <<"no_case">>).
-define(DEFAULT_RUN, <<"no_runid">>).
-define(DEFAULT_REV, <<"">>).
-define(DEFAULT_TIME,     <<"yyyy-mm-dd hh:mm:ss">>).
-define(DEFAULT_TIME_STR,   "yyyy-mm-dd hh:mm:ss").
-define(ONE_SEC, 1000).
-define(ONE_MIN, 60*?ONE_SEC).

-ifdef(OTP_RELEASE).
    -define(stacktrace(),
            fun() -> try throw(1) catch _:_:StAcK -> StAcK end end()).
    -define(CATCH_STACKTRACE(Class, Reason, Stacktrace),
            Class:Reason:Stacktrace ->
           ).
-else.
    -define(stacktrace(),
            try throw(1) catch _:_ -> erlang:get_stacktrace() end).
    -define(CATCH_STACKTRACE(Class, Reason, Stacktrace),
            Class:Reason ->
                Stacktrace = erlang:get_stacktrace(),
           ).
-endif.

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% Records

-record(cmd,
        {lineno :: non_neg_integer(),
         type   :: atom(),
         arg    :: term(),
         orig   :: binary()}).

-record(shell,
        {name            :: string(),
         pid             :: pid(),
         ref             :: reference(),
         health          :: alive | zombie,
         vars            :: [string()],                     % ["name=val"]
         match_timeout   :: infinity  | non_neg_integer(),
         fail_pattern    :: undefined | binary(),
         success_pattern :: undefined | binary()}).

-record(cmd_pos,
        {rev_file   :: [string()],
         lineno     :: non_neg_integer(),
         type       :: atom()}).

-record(warning,
        {file    :: filename(),
         lineno  :: lineno(),
         details :: binary()}).

-record(result,
        {outcome       :: fail | success | shutdown,
         mode          :: running | cleanup | stopping,
         shell_name    :: string(),
         latest_cmd    :: #cmd{},
         cmd_stack     :: [{string(), non_neg_integer(), atom()}],
         expected_tag  :: 'expected=' | 'expected*',
         expected      :: binary() | atom(),
         extra         :: undefined | atom() | binary(),
         actual        :: binary() | atom(),
         rest          :: binary() | atom(),
         events        :: [{non_neg_integer(),
                            atom(),
                            binary() | atom() | string()}],
         warnings      :: [#warning{}]}).

-record(break,
        {pos            :: {string(), non_neg_integer()} | [non_neg_integer()],
         invert = false :: boolean(),
         type           :: temporary  | next | skip | enabled | disabled}).

-record(macro,
        {name :: string(),
         file :: string(),
         cmd  :: #cmd{}}).

-record(loop,
        {mode :: iterate | break | #cmd{},
         cmd  :: #cmd{}}).

-record(debug_shell,
        {name :: string(),
         mode :: background | foreground,
         pid  :: pid()}).

-record(istate,
        {top_pid                    :: pid(),
         file                       :: string(),
         orig_file                  :: string(),
         mode = running             :: running | cleanup | stopping,
         warnings                   :: [#warning{}],
         loop_stack = []            :: [#loop{}],
         cleanup_reason = normal    :: fail | success | normal,
         debug = false              :: boolean(),
         debug_file                 :: string(),
         debug_pid                  :: pid(),
         trace_mode                 :: none | suite | 'case' | event | progress,
         skip = []                  :: [string()],
         skip_unless = []           :: [string()],
         unstable = []              :: [string()],
         unstable_unless = []       :: [string()],
         require = []               :: [string()],
         case_prefix = ""           :: string(),
         config_dir = undefined     :: undefined | string(),
         progress = brief           :: silent | summary | brief |
                                       doc | compact | verbose |
                                       etrace | ctrace,
         suite_log_dir = "lux_logs" :: string(),
         case_log_dir               :: string(),
         log_fun                    :: function(),
         config_log_fd              :: {true, file:io_device()},
         event_log_fd               :: {true, file:io_device()},
         summary_log_fd             :: file:io_device(),
         logs = []                  :: [{string(), string(), string()}],
         tail_status = []           :: [{string(), string()}],
         multiplier = ?ONE_SEC          :: non_neg_integer(),
         suite_timeout = infinity   :: non_neg_integer() | infinity,
         case_timeout = 5*?ONE_MIN  :: non_neg_integer() | infinity,
         case_timer_ref             :: reference(),
         flush_timeout = 0          :: non_neg_integer(),
         poll_timeout = 0           :: non_neg_integer(), % 100
         default_timeout = 10*?ONE_SEC  :: non_neg_integer() | infinity,
         cleanup_timeout = 100*?ONE_SEC :: non_neg_integer() | infinity,
         newshell = false           :: boolean(),
         shell_wrapper              :: undefined | string(),
         shell_cmd = "/bin/sh"      :: string(),
         shell_args = ["-i"]        :: [string()],
         shell_prompt_cmd = "export PS1=SH-PROMPT:" :: string(),
         shell_prompt_regexp = "^SH-PROMPT:" :: string(),
         call_level= 1              :: non_neg_integer(),
         results = []               :: [#result{} | {'EXIT', term()}],
         active_shell               :: undefined | #shell{},
         active_name = "lux"        :: undefined | string(),
         shells = []                :: [#shell{}],
         debug_shell                :: undefined | #debug_shell{},
         blocked                    :: boolean(),
         has_been_blocked           :: boolean(),
         want_more                  :: boolean(),
         old_want_more              :: boolean(),
         debug_level = 0            :: non_neg_integer(),
         breakpoints = []           :: [#break{}],
         commands                   :: [#cmd{}],
         orig_commands              :: [#cmd{}],
         macros = []                :: [#macro{}],
         cmd_stack = []             :: [{string(), non_neg_integer(), atom()}],
         submatch_vars = []         :: [string()],   % ["name=val"]
         macro_vars = []            :: [string()],   % ["name=val"]
         global_vars = []           :: [string()],   % ["name=val"]
         builtin_vars               :: [string()],   % ["name=val"]
         system_vars                :: [string()],   % ["name=val"]
         latest_cmd = #cmd{type = comment, lineno = 0, orig = <<>>}
                                    :: #cmd{},
         stopped_by_user            :: undefined | 'case' | suite}).


-record(run,
        {test = ?DEFAULT_SUITE
                      :: binary(),              % [prefix "::"] suite [":" case]
         result = fail
                      :: success | warning | skip | fail,
         id = ?DEFAULT_RUN
                      :: binary(),              % --run
         log = ?DEFAULT_LOG
                      :: file:filename(),       % file rel to summary log dir
         start_time = ?DEFAULT_TIME
                      :: binary(),
         branch       :: undefined | string(),
         hostname = ?DEFAULT_HOSTNAME
                      :: binary(),              % $HOSTNAME or --hostname
         config_name = ?DEFAULT_CONFIG_NAME
                      :: binary(),              % --config
         run_dir      :: file:filename(),       % current dir during run
         run_log_dir  :: file:dirname(),        % dir where logs was created
         new_log_dir  :: file:dirname(),        % top dir for new logs
         repos_rev = ?DEFAULT_REV
                      :: binary(),              % --revision
         details = [] :: [#run{}]}).            % list of cases

-record(source,
        {branch       :: undefined | string(),
         suite_prefix :: undefined | string(),
         file         :: file:filename(),       % relative to cwd
         dir          :: file:dirname(),        % relative to cwd
         orig         :: file:filename()}).

-record(event,
        {lineno  :: non_neg_integer(),
         shell   :: binary(),
         op      :: binary(),
         quote   :: quote | plain,
         data    :: [binary()]}).

-record(body,
        {invoke_lineno :: integer(),
         first_lineno  :: non_neg_integer(),
         last_lineno   :: non_neg_integer(),
         file          :: file:filename(),
         events        :: [#event{}]}).

-record(timer,
        {match_lineno :: [integer()], % Reversed stack of lineno
         match_data   :: [binary()],
         send_lineno  :: [integer()], % Reversed stack of lineno
         send_data    :: [binary()],
         shell        :: binary(),                        % Name
         callstack    :: binary(),                        % Name->Name->Name
         macro        :: binary(),                        % Name
         max_time     :: infinity | non_neg_integer(),    % Micros
         status       :: expected | started | matched | failed,
         elapsed_time :: undefined | non_neg_integer()}). % Micros

-record(pattern,
        {cmd       :: #cmd{},
         cmd_stack :: [{string(), non_neg_integer(), atom()}]}).

-record(cstate,
        {orig_file               :: string(),
         parent                  :: pid(),
         name                    :: string(),
         debug = disconnect      :: connect | disconnect,
         latest_cmd              :: #cmd{},
         cmd_stack = []          :: [{string(), non_neg_integer(), atom()}],
         wait_for_expect         :: undefined | pid(),
         mode = resume           :: resume | suspend,
         start_reason            :: fail | success | normal,
         progress                :: silent | summary | brief |
                                    doc | compact | verbose |
                                    etrace | ctrace,
         log_fun                 :: function(),
         log_prefix              :: string(),
         event_log_fd            :: {true, file:io_device()},
         stdin_log_fd            :: {false, file:io_device()},
         stdout_log_fd           :: {false, file:io_device()},
         multiplier              :: non_neg_integer(),
         poll_timeout            :: non_neg_integer(),
         flush_timeout           :: non_neg_integer(),
         match_timeout           :: non_neg_integer() | infinity,
         shell_wrapper           :: undefined | string(),
         shell_cmd               :: string(),
         shell_args              :: [string()],
         shell_prompt_cmd        :: string(),
         shell_prompt_regexp     :: string(),
         port                    :: port(),
         waiting = false         :: boolean(),
         fail                    :: undefined | #pattern{},
         success                 :: undefined | #pattern{},
         loop_stack = []         :: [#loop{}],
         expected                :: undefined | #cmd{},
         pre_expected = []       :: [#cmd{}],
         actual = <<>>           :: binary(),
         state_changed = false   :: boolean(),
         timed_out = false       :: boolean(),
         idle_count = 0          :: non_neg_integer(),
         no_more_input = false   :: boolean(),
         no_more_output = false  :: boolean(),
         exit_status             :: integer(),
         timer                   :: undefined | infinity | reference(),
         timer_started_at        :: undefined | {non_neg_integer(),
                                                 non_neg_integer(),
                                                 non_neg_integer()},
         wakeup                  :: undefined | reference(),
         debug_level = 0         :: non_neg_integer(),
         events = []             :: [tuple()],
         warnings = []           :: [#warning{}]}).

-record(rstate,
        {files                      :: [string()],
         orig_files                 :: [string()],
         orig_args                  :: [string()],
         user_log_dir               :: undefined | string(),
         prev_log_dir               :: undefined | string(),
         mode = execute             :: lux:run_mode(),
         skip_unstable = false      :: boolean(),
         skip_skip = false          :: boolean(),
         progress = brief           :: silent | summary | brief |
                                       doc | compact | verbose |
                                       etrace | ctrace,
         config_dir                 :: string(),
         file_pattern = "^[^\\\.].*\\\.lux" ++ [$$] :: string(),
         case_prefix = ""           :: string(),
         log_fd                     :: file:io_device(),
         log_dir                    :: file:filename(),
         summary_log                :: string(),
         config_name                :: string(),
         config_file                :: string(),
         suite = ?b2l(?DEFAULT_SUITE) :: string(),
         start_time                 :: {non_neg_integer(),
                                        non_neg_integer(),
                                        non_neg_integer()},
         run                        :: string(),
         extend_run = false         :: boolean(),
         revision = ""              :: string(),
         hostname = lux_utils:real_hostname() :: string(),
         rerun = disable            :: enable | success | skip | warning |
                                       fail | error | disable,
         html = enable              :: validate |
                                       enable | success | skip | warning |
                                       fail | error | disable,
         warnings = []              :: [#warning{}],
         internal_args = []         :: [{atom(), term()}], % Internal opts
         user_args = []             :: [{atom(), term()}], % Command line opts
         file_args = []             :: [{atom(), term()}], % Script opts
         config_args = []           :: [{atom(), term()}], % Arch spec opts
         default_args = []          :: [{atom(), term()}], % Default opts
         builtin_vars = lux_utils:builtin_vars()
                                    :: [string()], % ["name=val"]
         system_vars = lux_utils:system_vars()
                                    :: [string()], % ["name=val"]
         tap_opts = []              :: [string()],
         tap                        :: term(), % #tap{}
         junit = false              :: boolean()
        }).

-record(pstate,
        {file           :: string(),
         orig_file      :: string(),
         pos_stack      :: [#cmd_pos{}],
         mode           :: lux:run_mode(),
         skip_unstable  :: boolean(),
         skip_skip      :: boolean(),
         multi_vars     :: [[string()]], % ["name=val"]
         warnings       :: [binary()],
         has_cleanup = false :: boolean(),
         top_doc        :: undefined | non_neg_integer(),
         newshell       :: boolean()
        }).

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% Types

-type filename() :: string().
-type dirname()  :: string().
-type opts()     :: [{atom(), term()}].
-type cmds()     :: [#cmd{}].
-type summary()  :: success | skip | warning | fail | error.
-type lineno()   :: string().
-type skip()     :: {skip, filename(), string()}.
-type error()    :: {error, filename(), string()}.
-type no_input() :: {error, undefined, no_input_files}.
-type result()   :: {ok, filename(), summary(), lineno(), [#warning{}]}.
-type run_mode() :: list | list_dir | doc | validate | execute.
