% @author Joseph Abrahamson <me@jspha.com>
%% @copyright 2012 Joseph Abrahamson

%% @doc Snowstorm, a gen_server which generates snowflakes en masse.

-module(sf_snowstorm).
-author('Joseph Abrahamson <me@jspha.com>').

-behaviour(gen_server).
-export([init/1,
	 terminate/2,
	 code_change/3,
	 handle_call/3,
	 handle_cast/2,
	 handle_info/2]).
-define(SERVER, ?MODULE).

-export([start/1, start_link/1]).

-define(TIMESTAMP_SIZE, 42).
-define(MACHINE_ID_SIZE, 10).
-define(COUNTER_SIZE, 12).

%% The gen_server state
-record(st, 
	{name :: atom(),
	 last :: integer(),
	 machine :: integer(),
	 count :: integer()}).


%% --------------------
%% Gen_Server callbacks

init([Name]) ->
    {ok, #st{name = Name, last = snowflake_now(),
	     count = 0, machine = machine_id()}}.
    
handle_call(new, _From, State = #st{last = Last, 
				    machine = MID, 
				    count = Count}) ->
    Now = snowflake_now(),
    SID = case Now of
	      Last -> Count;
	      %% New time point, reset the counter.
	      _    -> 0
	  end,
    {reply, 
     <<Now:?TIMESTAMP_SIZE, MID:?MACHINE_ID_SIZE, SID:?COUNTER_SIZE>>, 
     State#st{last = Now, count = SID+1}}.

handle_cast(_Message, State) -> {noreply, State}.
handle_info(_Message, State) -> {noreply, State}.
terminate(_Reason, _State) -> ok.
code_change(_OldVsn, State, _Extra) -> {ok, State}.


%% ------------------
%% Lifecycle dynamics

start(Name) ->
    gen_server:start(?SERVER, [Name], []).

start_link(Name) ->
    gen_server:start_link(?SERVER, [Name], []).


%% ---------
%% Utilities

-spec 
%% @doc returns the number of milliseconds since UTC January 1st,
%% 2012.
snowflake_now() -> integer().
snowflake_now() ->
	SnowflakeEPOCH = 1325376000000,  % 2012-01-01T00:00:00Z - 1970-01-01T00:00:00Z in milliseconds
	os:system_time(millisecond) - SnowflakeEPOCH.

-spec 
machine_id() -> integer().
machine_id() ->
	{ok, MID} = application:get_env(machine_id),
	machine_id(MID).

-spec 
machine_id(integer() | hostname_hash | {env, os:env_var_name()}) -> integer().
machine_id(MID) when is_integer(MID) ->
	MID;
machine_id(hostname_hash) ->
	{ok, Hostname} = inet:gethostname(),
	erlang:phash2(Hostname, 1 bsl ?MACHINE_ID_SIZE);
machine_id({env, Name}) ->
	case os:getenv(Name) of
		false ->
			erlang:error({non_existing_env_variable, Name});
		Value ->
			erlang:list_to_integer(Value)
	end.
