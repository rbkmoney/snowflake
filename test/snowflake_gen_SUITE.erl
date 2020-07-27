-module(snowflake_gen_SUITE).

-include_lib("stdlib/include/assert.hrl").

-export([all/0]).

-export([timestamp_init_validation_test/1]).
-export([machine_id_init_validation_test/1]).
-export([timestamp_gen_validation_test/1]).
-export([monotonic_test/1]).
-export([backward_clock_moving_test/1]).
-export([confugurable_backward_clock_moving_test/1]).
-export([exhausted_test/1]).

-type config() :: [{atom(), term()}].
-type test_case_name() :: atom().
-type test_return()    :: _ | no_return().

-type gen() :: snowflake_gen:state().
-type uuid() :: snowflake_gen:uuid().
-type time() :: snowflake_gen:time().
-type machine_id() :: snowflake_gen:machine_id().

-spec all() -> [test_case_name()].
all() ->
    [
        timestamp_init_validation_test,
        machine_id_init_validation_test,
        timestamp_gen_validation_test,
        monotonic_test,
        backward_clock_moving_test,
        confugurable_backward_clock_moving_test,
        exhausted_test
    ].

-spec timestamp_init_validation_test(config()) -> test_return().
timestamp_init_validation_test(_C) ->
    TooLittleTime = -1,
    TooBigTime = 1 bsl snowflake_gen:timestamp_size(),
    ?assertEqual({error, {invalid_timestamp, TooLittleTime}}, new(TooLittleTime, 0)),
    ?assertEqual({error, {timestamp_too_large, TooBigTime}}, new(TooBigTime, 0)).

-spec machine_id_init_validation_test(config()) -> test_return().
machine_id_init_validation_test(_C) ->
    TooLittleID = -1,
    TooBigID = 1 bsl snowflake_gen:timestamp_size(),
    ?assertEqual({error, {invalid_machine_id, TooLittleID}}, new(0, TooLittleID)),
    ?assertEqual({error, {machine_id_too_large, TooBigID}}, new(0, TooBigID)).

-spec timestamp_gen_validation_test(config()) -> test_return().
timestamp_gen_validation_test(_C) ->
    {ok, Gen} = new(0, 0),
    TooLittleTime = -1,
    TooBigTime = 1 bsl snowflake_gen:timestamp_size(),
    ?assertMatch({{error, {invalid_timestamp, TooLittleTime}}, _}, snowflake_gen:next(TooLittleTime, Gen)),
    ?assertMatch({{error, {timestamp_too_large, TooBigTime}}, _}, snowflake_gen:next(TooBigTime, Gen)).

-spec monotonic_test(config()) -> test_return().
monotonic_test(_C) ->
    {ok, Gen} = new(sf_time(), 0),
    Time = sf_time(),
    {_Gen, IDs} = lists:foldl(
        fun(T, {GenSt, Acc}) ->
            {ok, Result, NewGenSt} = generate_ids(1 bsl snowflake_gen:counter_size(), T, GenSt),
            {NewGenSt, Acc ++ Result}
        end,
        {Gen, []},
        [Time, Time + 1, Time + 2, Time + 3]
    ),
    ?assertEqual(IDs, lists:usort(IDs)).

-spec backward_clock_moving_test(config()) -> test_return().
backward_clock_moving_test(_C) ->
    Time = sf_time(),
    NewTime = Time - 1,
    {ok, Gen} = new(Time, 0),
    ?assertMatch({{error, {backward_clock_moving, Time, NewTime}}, _}, snowflake_gen:next(NewTime, Gen)).

-spec confugurable_backward_clock_moving_test(config()) -> test_return().
confugurable_backward_clock_moving_test(_C) ->
    Time = sf_time(),
    {ok, Gen} = snowflake_gen:new(#{
        initial_timestamp => Time,
        machine_id => 0,
        max_backward_clock_moving => 100
    }),
    ?assertMatch({{ok, _}, _}, snowflake_gen:next(Time + 1, Gen)),
    ?assertMatch({{ok, _}, _}, snowflake_gen:next(Time + 0, Gen)),
    ?assertMatch({{ok, _}, _}, snowflake_gen:next(Time - 1, Gen)),
    ?assertMatch({{ok, _}, _}, snowflake_gen:next(Time - 99, Gen)),
    ?assertMatch({{ok, _}, _}, snowflake_gen:next(Time - 100, Gen)),
    ?assertMatch({{error, {backward_clock_moving, Time, _}}, _}, snowflake_gen:next(Time - 101, Gen)).

-spec exhausted_test(config()) -> test_return().
exhausted_test(_C) ->
    {ok, Gen} = new(sf_time(), 0),
    ?assertMatch({error, exhausted, _}, generate_ids((1 bsl snowflake_gen:counter_size()) + 1, sf_time(), Gen)).

%% Utils

-spec new(time(), machine_id()) ->
    {ok, gen()} | {error, term()}.
new(Time, MachineID) ->
    snowflake_gen:new(#{
        initial_timestamp => Time,
        machine_id => MachineID
    }).

-spec generate_ids(non_neg_integer(), time(), gen()) ->
    {ok, [uuid()], gen()} |
    {error, snowflake_gen:generation_error_reason(), gen()}.
generate_ids(Count, Time, GenSt) ->
    generate_ids(Count, Time, GenSt, []).

-spec generate_ids(non_neg_integer(), time(), gen(), [uuid()]) ->
    {ok, [uuid()], gen()} |
    {error, snowflake_gen:generation_error_reason(), gen()}.
generate_ids(0, _Time, GenSt, Acc) ->
    {ok, lists:reverse(Acc), GenSt};
generate_ids(Count, Time, GenSt, Acc) when Count > 0 ->
    case snowflake_gen:next(Time, GenSt) of
        {{ok, ID}, NewGen} ->
            generate_ids(Count - 1, Time, NewGen, [ID | Acc]);
        {{error, Reason}, NewGen} ->
            {error, Reason, NewGen}
    end.

-spec sf_time() -> time().
sf_time() ->
    SnowflakeEPOCH = 1325376000000,  % 2012-01-01T00:00:00Z - 1970-01-01T00:00:00Z in milliseconds
    os:system_time(millisecond) - SnowflakeEPOCH.
