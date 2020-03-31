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
    {error, {invalid_machine_id, integer()} | {invalid_timestamp, integer()}}.
new(Time, _MachineID) when Time >= (1 bsl ?TIMESTAMP_SIZE) orelse Time < 0 ->
    {error, {invalid_timestamp, Time}};
new(_Time, MachineID) when MachineID >= (1 bsl ?MACHINE_ID_SIZE) orelse MachineID < 0 ->
    {error, {invalid_machine_id, MachineID}};
new(Time, MachineID) ->
    {ok, #state{
        machine = MachineID,
        last = Time,
        count = 0
    }}.

-spec next(time(), state()) ->
    {ok, uuid(), state()} |
    {error, generation_error_reason()}.
next(Time, _State) when Time >= (1 bsl ?TIMESTAMP_SIZE) orelse Time < 0 ->
    {error, {invalid_timestamp, Time}};
next(Time, #state{last = Last}) when Time < Last ->
    {error, {backward_clock_moving, Last, Time}};
next(Time, #state{last = Last} = State) when Time > Last ->
    next(Time, State#state{last = Time, count = 0});
next(Time, #state{count = Count, last = Last}) when Time =:= Last andalso Count >= (1 bsl ?COUNTER_SIZE) ->
    {error, exhausted};
next(Time, #state{count = Count, last = Last, machine = MachineID} = State) when Time =:= Last ->
    ID = <<Last:?TIMESTAMP_SIZE, MachineID:?MACHINE_ID_SIZE, Count:?COUNTER_SIZE>>,
    {ok, ID, State#state{count = Count + 1}}.
