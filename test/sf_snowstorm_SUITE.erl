-module(sf_snowstorm_SUITE).

-include_lib("stdlib/include/assert.hrl").

-export([all/0]).

-export([machine_id_integer_test/1]).
-export([machine_id_integer_fail_test/1]).
-export([machine_id_hostname_hash_test/1]).
-export([machine_id_env_test/1]).
-export([machine_id_env_fail_test/1]).
-export([machine_id_env_match_test/1]).
-export([machine_id_env_match_fail_test/1]).

-type config() :: [{atom(), term()}].
-type test_case_name() :: atom().
-type test_return()    :: _ | no_return().

-spec all() -> [test_case_name()].
all() ->
    [
        machine_id_integer_test,
        machine_id_integer_fail_test,
        machine_id_hostname_hash_test,
        machine_id_env_test,
        machine_id_env_fail_test,
        machine_id_env_match_test,
        machine_id_env_match_fail_test
    ].

-spec machine_id_integer_test(config()) -> test_return().
machine_id_integer_test(_C) ->
    ok = application:set_env(snowflake, machine_id, 1),
    ok = application:set_env(snowflake, max_backward_clock_moving, 1000),
    {ok, _Pid} = sf_snowstorm:start(name).

-spec machine_id_integer_fail_test(config()) -> test_return().
machine_id_integer_fail_test(_C) ->
    ok = application:set_env(snowflake, machine_id, <<1>>),
    ok = application:set_env(snowflake, max_backward_clock_moving, 1000),
    {error, {function_clause, _}} = sf_snowstorm:start(name).

-spec machine_id_hostname_hash_test(config()) -> test_return().
machine_id_hostname_hash_test(_C) ->
    ok = application:set_env(snowflake, machine_id, hostname_hash),
    ok = application:set_env(snowflake, max_backward_clock_moving, 1000),
    {ok, _Pid} = sf_snowstorm:start(name).

-spec machine_id_env_test(config()) -> test_return().
machine_id_env_test(_C) ->
    true = os:set_env_var("MY_ENV", "1"),
    ok = application:set_env(snowflake, machine_id, {env, "MY_ENV"}),
    ok = application:set_env(snowflake, max_backward_clock_moving, 1000),
    {ok, _Pid} = sf_snowstorm:start(name).

-spec machine_id_env_fail_test(config()) -> test_return().
machine_id_env_fail_test(_C) ->
    true = os:set_env_var("MY_ENV", "g"),
    ok = application:set_env(snowflake, machine_id, {env, "MY_ENV"}),
    ok = application:set_env(snowflake, max_backward_clock_moving, 1000),
    {error, {badarg, _}} = sf_snowstorm:start(name).

-spec machine_id_env_match_test(config()) -> test_return().
machine_id_env_match_test(_C) ->
    true = os:set_env_var("MY_ENV", "myapp-1"),
    ok = application:set_env(snowflake, machine_id, {env_match, "MY_ENV", "(?!-)([0-9]+)$"}),
    ok = application:set_env(snowflake, max_backward_clock_moving, 1000),
    {ok, _Pid} = sf_snowstorm:start(name).

-spec machine_id_env_match_fail_test(config()) -> test_return().
machine_id_env_match_fail_test(_C) ->
    Env = "myapp-",
    Regex = "(?!-)([0-9]+)$",
    true = os:set_env_var("MY_ENV", Env),
    ok = application:set_env(snowflake, machine_id, {env_match, "MY_ENV", Regex}),
    ok = application:set_env(snowflake, max_backward_clock_moving, 1000),
    {error, {{nomatch_env_variable, Env, Regex}, _}} = sf_snowstorm:start(name).
