-module(python_worker_srv).
-behaviour(gen_server).

-export([start_link/0, send_message/1]).
-export([init/1, handle_call/3, handle_cast/2, handle_info/2, terminate/2, code_change/3]).

-record(state, {port}).

start_link() ->
    gen_server:start_link({local, ?MODULE}, ?MODULE, [], []).

send_message(Msg) ->
    gen_server:call(?MODULE, {send, Msg}).

init([]) ->
    process_flag(trap_exit, true),
    %% Get python script path from env, fallback to relative path
    ScriptPath = application:get_env(erlang_orchestrator, python_worker_script, "../python_worker/worker.py"),
    Cmd = "python3 " ++ ScriptPath,
    Port = open_port({spawn, Cmd}, [stream, {line, 256}, exit_status]),
    {ok, #state{port = Port}}.

handle_call({send, Msg}, _From, State = #state{port = Port}) ->
    port_command(Port, Msg ++ "\n"),
    {reply, ok, State};
handle_call(_Request, _From, State) ->
    {reply, ok, State}.

handle_cast(_Msg, State) ->
    {noreply, State}.

handle_info({Port, {data, {eol, Line}}}, State = #state{port = Port}) ->
    io:format("Received from Python: ~p~n", [Line]),
    {noreply, State};
handle_info({Port, {exit_status, Status}}, State = #state{port = Port}) ->
    io:format("Python worker exited with status ~p~n", [Status]),
    {stop, {port_exit, Status}, State};
handle_info(_Info, State) ->
    {noreply, State}.

terminate(_Reason, #state{port = Port}) ->
    port_close(Port),
    ok.

code_change(_OldVsn, State, _Extra) ->
    {ok, State}.
