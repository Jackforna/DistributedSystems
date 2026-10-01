%%% Bridge asincrono tra la VM Erlang (Control Plane) e l'engine Python (Data Plane).
%%% Gestione della Port I/O di sistema, garantendo il routing dei risultati e l'isolamento dei guasti.

-module(python_worker_srv).
-behaviour(gen_server).

-export([start_link/0, send_message/1]).
-export([init/1, handle_call/3, handle_cast/2, handle_info/2, terminate/2, code_change/3]).

-record(state, {port}).

%% Callback del gen_server

start_link() ->
    gen_server:start_link({local, ?MODULE}, ?MODULE, [], []).

send_message(Msg) ->
    gen_server:call(?MODULE, {send, Msg}).


%% Estrazione dinamica del path dello script per evitare percorsi hardcoded
%% e avviamento del processo figlio del sistema operativo tramite flussi Standard I/O.
init([]) ->
    process_flag(trap_exit, true),
    %% Lettura del percorso dello script Python dall'ambiente, con percorso relativo di default
    ScriptPath = application:get_env(erlang_orchestrator, python_worker_script, "../python_worker/worker.py"),
    Cmd = "python3 " ++ ScriptPath,
    Port = open_port({spawn, Cmd}, [stream, {line, 256}, exit_status]),
    {ok, #state{port = Port}}.

handle_call({send, Msg}, _From, State = #state{port = Port}) ->
    port_command(Port, Msg ++ "\n"),
    {reply, ok, State};
handle_call(_Request, _From, State) ->
    {reply, ok, State}.

%% Invia un comando testuale (es. TRAIN o AGGREGATE) al processo Python.
%% Usiamo port_command per iniettare il payload nello Standard Input del demone.
handle_cast(_Msg, State) ->
    {noreply, State}.

%% Reactor Pattern: intercettazione asincrona dell'output (Standard Output) di Python.
%% Invece di bloccare questo server, instradiamo il risultato al manager del round.
handle_info({Port, {data, {eol, Line}}}, State = #state{port = Port}) ->
    io:format("Received from Python: ~p~n", [Line]),
    %% Parsing dei messaggi in base al prefisso
    case lists:splitwith(fun(C) -> C =/= $| end, Line) of
        {"TRAIN_RES", "|" ++ TrainRes} ->
            gen_server:cast(fl_manager_srv, {python_result, TrainRes});
        {"AGGREGATE_RES", "|" ++ AggRes} ->
            gen_server:cast(fl_manager_srv, {aggregated_result, AggRes});
        _ ->
            %% Gestione degli altri messaggi
            gen_server:cast(fl_manager_srv, {python_result, Line})
    end,
    {noreply, State};

%% Fault Isolation: intercettazione della morte anomala del processo OS (es. SIGKILL o OOM).
%% Il crash controllato di questo actor innescherà la policy one_for_one del Supervisor.
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