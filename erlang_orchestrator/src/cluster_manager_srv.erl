-module(cluster_manager_srv).
-behaviour(gen_server).

-export([start_link/0]).
-export([init/1, handle_call/3, handle_cast/2, handle_info/2, terminate/2, code_change/3]).

-record(state, {}).

start_link() ->
    gen_server:start_link({local, ?MODULE}, ?MODULE, [], []).

init([]) ->
    %% Eseguiamo il ping in modo asincrono inviando un messaggio a noi stessi
    %% per non bloccare l'avvio del supervisor.
    self() ! discover_nodes,
    {ok, #state{}}.

handle_call(_Request, _From, State) ->
    {reply, ok, State}.

handle_cast(_Msg, State) ->
    {noreply, State}.

handle_info(discover_nodes, State) ->
    %% Leggiamo la lista dei nodi dall'ambiente (default lista vuota se assente)
    Nodes = application:get_env(erlang_orchestrator, seed_nodes, []),
    lists:foreach(fun ping_node/1, Nodes),
    {noreply, State};
handle_info(_Info, State) ->
    {noreply, State}.

terminate(_Reason, _State) ->
    ok.

code_change(_OldVsn, State, _Extra) ->
    {ok, State}.

%% --- Internal Functions ---
ping_node(Node) ->
    case net_adm:ping(Node) of
        pong ->
            io:format("~c[32m✅ Connesso al nodo ~p~c[0m~n", [27, Node, 27]);
        pang ->
            io:format("~c[33m⚠️ Impossibile raggiungere il nodo ~p~c[0m~n", [27, Node, 27])
    end.
