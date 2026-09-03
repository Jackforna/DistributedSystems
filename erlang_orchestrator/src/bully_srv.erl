-module(bully_srv).
-behaviour(gen_server).

-export([start_link/0, start_election/0, get_leader/0]).
-export([init/1, handle_call/3, handle_cast/2, handle_info/2, terminate/2, code_change/3]).

-record(state, {leader = undefined, timer = undefined}).

start_link() ->
    gen_server:start_link({local, ?MODULE}, ?MODULE, [], []).

start_election() ->
    gen_server:cast(?MODULE, start_election).

get_leader() ->
    gen_server:call(?MODULE, get_leader).

init([]) ->
    %% L'elezione non parte in automatico all'avvio del processo per lasciare 
    %% tempo all'auto-discovery di formare il cluster. 
    %% Si può chiamare bully_srv:start_election() manualmente, oppure
    %% triggerarlo da eventi di clusterizzazione in seguito.
    {ok, #state{}}.

handle_call(get_leader, _From, State) ->
    {reply, State#state.leader, State};
handle_call(_Request, _From, State) ->
    {reply, ok, State}.

handle_cast(start_election, State) ->
    io:format("~c[33m⚔️ [ELECTION] Sfido i nodi maggiori~c[0m~n", [27, 27]),
    HigherNodes = [N || N <- nodes(), N > node()],
    NewState = case HigherNodes of
        [] ->
            %% Nessun nodo maggiore, diventiamo subito Leader
            self() ! become_leader,
            State;
        _ ->
            %% Invia messaggio di elezione ai nodi maggiori
            lists:foreach(fun(Node) ->
                gen_server:cast({?MODULE, Node}, {election, node()})
            end, HigherNodes),
            %% Cancella eventuale timer precedente
            if State#state.timer =/= undefined -> erlang:cancel_timer(State#state.timer); true -> ok end,
            %% Imposta un timer di 2000ms
            Timer = erlang:send_after(2000, self(), election_timeout),
            State#state{timer = Timer}
    end,
    {noreply, NewState};

handle_cast({election, FromNode}, State) ->
    %% Un nodo con ID minore ci sfida. Rispondiamo 'alive' per fermarlo.
    gen_server:cast({?MODULE, FromNode}, {alive, node()}),
    %% Poiché l'elezione è stata indetta, dobbiamo partecipare anche noi sfidando
    %% a nostra volta i nodi più grandi.
    gen_server:cast(?MODULE, start_election),
    {noreply, State};

handle_cast({alive, _FromNode}, State) ->
    %% Un nodo maggiore ha risposto. Annulliamo la nostra scalata al potere.
    io:format("~c[34m🛡️ [ELECTION] Ricevuto alive. Fermo l'elezione.~c[0m~n", [27, 27]),
    case State#state.timer of
        undefined -> ok;
        Timer -> erlang:cancel_timer(Timer)
    end,
    {noreply, State#state{timer = undefined}};

handle_cast({coordinator, LeaderNode}, State) ->
    %% Aggiorniamo il leader riconosciuto
    io:format("~c[36m👁️ [ELECTION] Riconosco come Leader: ~p~c[0m~n", [27, LeaderNode, 27]),
    {noreply, State#state{leader = LeaderNode}};

handle_cast(_Msg, State) ->
    {noreply, State}.

handle_info(election_timeout, State) ->
    %% Nessun nodo maggiore ha risposto entro il timeout.
    self() ! become_leader,
    {noreply, State#state{timer = undefined}};

handle_info(become_leader, State) ->
    io:format("~c[32m👑 [ELECTION] Sono il nuovo Leader!~c[0m~n", [27, 27]),
    %% Dico a tutti gli altri nodi (compresi quelli inferiori) che sono io il leader
    lists:foreach(fun(Node) ->
        gen_server:cast({?MODULE, Node}, {coordinator, node()})
    end, nodes()),
    {noreply, State#state{leader = node()}};

handle_info(_Info, State) ->
    {noreply, State}.

terminate(_Reason, _State) ->
    ok.

code_change(_OldVsn, State, _Extra) ->
    {ok, State}.
