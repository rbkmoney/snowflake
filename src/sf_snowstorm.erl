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

%% The gen_server state
-record(st,
	{name :: atom(),
	 gen :: snowflake_gen:state()}).


%% --------------------
%% Gen_Server callbacks

init([Name]) ->
	Options = #{
		initial_timestamp => snowflake_now(),
		machine_id => machine_id(),
		max_backward_clock_moving => max_backward_clock_moving()
	},
	{ok, Gen} = snowflake_gen:new(Options),
    {ok, #st{name = Name, gen = Gen}}.
    
handle_call(new, _From, State = #st{gen = GenSt}) ->
    {Reply, NewGenSt} = snowflake_gen:next(snowflake_now(), GenSt),
    {reply, Reply, State#st{gen = NewGenSt}}.

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
	{ok, MID} = application:get_env(snowflake, machine_id),
	machine_id(MID).

-spec 
max_backward_clock_moving() -> non_neg_integer().
max_backward_clock_moving() ->
	case application:get_env(snowflake, max_backward_clock_moving) of
		{ok, Max} ->
			Max;
		undefined ->
			0
	end.

-spec 
machine_id(integer() | hostname_hash | {env, os:env_var_name()}) -> integer().
machine_id(MID) when is_integer(MID) ->
	MID;
machine_id(hostname_hash) ->
	{ok, Hostname} = inet:gethostname(),
	erlang:phash2(Hostname, 1 bsl snowflake_gen:machine_id_size());
machine_id({env, Name}) ->
	case os:getenv(Name) of
		false ->
			erlang:error({non_existing_env_variable, Name});
		Value ->
			erlang:list_to_integer(Value)
	end;
machine_id({env_match, Name, Regex}) ->
	case os:getenv(Name) of
		false ->
			erlang:error({non_existing_env_variable, Name});
		Value ->
			case re:run(Value, Regex, [{capture, [0], list}]) of
				{match, [Matched| _]} ->
					erlang:list_to_integer(Matched);
				nomatch ->
					erlang:error({nomatch_env_variable, Value, Regex})
			end
	end.
