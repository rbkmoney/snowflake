-module(snowflake_gen).

-export([timestamp_size/0]).
-export([machine_id_size/0]).
-export([counter_size/0]).
-export([new/2]).
-export([next/2]).

-export_type([uuid/0]).
-export_type([machine_id/0]).
-export_type([time/0]).
-export_type([state/0]).
-export_type([generation_error_reason/0]).

-type uuid() :: <<_:64>>.
-type machine_id() :: non_neg_integer().
-type time() :: non_neg_integer().
-type generation_error_reason() ::
    {backward_clock_moving, Last :: time(), New :: time()} |
    {timestamp_too_large, Time :: time()} |
    {invalid_timestamp, Time :: integer()} |
    exhausted.


-record(state, {
    last :: time(),
    machine :: machine_id(),
    count :: counter()
}).
-opaque state() :: state().

%% Internal types

-type counter() :: non_neg_integer().

%% Constants

-define(TIMESTAMP_SIZE, 42).
-define(MACHINE_ID_SIZE, 10).
-define(COUNTER_SIZE, 12).

%% API

-spec timestamp_size() -> pos_integer().
timestamp_size() ->
    ?TIMESTAMP_SIZE.

-spec machine_id_size() -> pos_integer().
machine_id_size() ->
    ?MACHINE_ID_SIZE.

-spec counter_size() -> pos_integer().
counter_size() ->
    ?COUNTER_SIZE.

-spec new(time(), machine_id()) ->
    {ok, state()} |
    {error, {invalid_machine_id, integer()} |
            {machine_id_too_large, integer()} |
            {timestamp_too_large, integer()} |
            {invalid_timestamp, integer()}}.
new(Time, _MachineID) when Time >= (1 bsl ?TIMESTAMP_SIZE) ->
    {error, {timestamp_too_large, Time}};
new(Time, _MachineID) when Time < 0 ->
    {error, {invalid_timestamp, Time}};
new(_Time, MachineID) when MachineID >= (1 bsl ?MACHINE_ID_SIZE) ->
    {error, {machine_id_too_large, MachineID}};
new(_Time, MachineID) when MachineID < 0 ->
    {error, {invalid_machine_id, MachineID}};
new(Time, MachineID) ->
    {ok, #state{
        machine = MachineID,
        last = Time,
        count = 0
    }}.

-spec next(time(), state()) -> {Result, state()} when
    Result :: {ok, uuid()} | {error, generation_error_reason()}.
next(Time, State) when Time >= (1 bsl ?TIMESTAMP_SIZE) ->
    {{error, {timestamp_too_large, Time}}, State};
next(Time, #state{last = Last} = State) when Time < Last ->
    {{error, {backward_clock_moving, Last, Time}}, State};
next(Time, #state{last = Last} = State) when Time > Last ->
    next(Time, State#state{last = Time, count = 0});
next(Time, #state{count = Count, last = Time} = State) when Count >= (1 bsl ?COUNTER_SIZE) ->
    {{error, exhausted}, State};
next(Time, #state{count = Count, last = Time, machine = MachineID} = State) ->
    ID = <<Time:?TIMESTAMP_SIZE, MachineID:?MACHINE_ID_SIZE, Count:?COUNTER_SIZE>>,
    {{ok, ID}, State#state{count = Count + 1}}.
