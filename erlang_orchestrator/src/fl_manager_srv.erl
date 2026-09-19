-module(fl_manager_srv).
-behaviour(gen_server).

-export([start_link/0, start_round/0]).
-export([init/1, handle_call/3, handle_cast/2, handle_info/2, terminate/2, code_change/3]).

-record(state, {leader_node = undefined, accumulated_weights = [], expected_nodes = 0}).

start_link() ->
    gen_server:start_link({local, ?MODULE}, ?MODULE, [], []).

start_round() ->
    %% Chiama l'inizio del round (eseguito dal Leader)
    gen_server:cast(?MODULE, start_round).

init([]) ->
    {ok, #state{}}.

handle_call(_Request, _From, State) ->
    {reply, ok, State}.

handle_cast(start_round, State) ->
    %% Impostiamo quanti nodi ci aspettiamo che rispondano (tutti,cluso il leader stesso)
    Expected = length(nodes()) + 1,
    %% Il leader avvia il round trasmettendo a tutti i nodi (incluso sé stesso)
    %% il comando di train.
    lists:foreach(fun(Node) ->
        gen_server:cast({?MODULE, Node}, {train_command, node()})
    end, nodes() ++ [node()]),
    {noreply, State#state{accumulated_weights = [], expected_nodes = Expected}};

handle_cast({train_command, LeaderNode}, State) ->
    %% Riceviamo l'ordine di train dal leader.
    %% Triggeriamo il python worker passandogli l'input TRAIN
    python_worker_srv:send_message("TRAIN"),
    {noreply, State#state{leader_node = LeaderNode}};

handle_cast({python_result, Data}, State = #state{leader_node = LeaderNode}) ->
    %% Il python worker ha terminato e ci ha restituito il dato (array di pesi JSON)
    %% Inoltriamo il payload al manager del LeaderNode.
    if LeaderNode =/= undefined ->
        gen_server:cast({?MODULE, LeaderNode}, {weights_payload, node(), Data});
    true ->
        io:format("⚠️ [FL-MANAGER] Nessun leader settato, ignoro il risultato.~n")
    end,
    {noreply, State};

handle_cast({weights_payload, FromNode, Data}, State = #state{accumulated_weights = Acc, expected_nodes = Expected}) ->
    %% Questo viene ricevuto dal leader che accumula i pesi.
    io:format("~c[32m📥 [FL-MANAGER] Ricevuti pesi dal nodo ~p: ~p~c[0m~n", [27, FromNode, Data, 27]),
    NewAcc = [Data | Acc],
    NewState = State#state{accumulated_weights = NewAcc},
    if length(NewAcc) >= Expected andalso Expected > 0 ->
        %% Abbiamo raccolto tutti i pesi dai nodi attesi. 
        %% Uniamo manualmente gli array stringa per formare un JSON valido (lista di liste)
        Payload = "[" ++ string:join(NewAcc, ",") ++ "]",
        %% Mandiamo al python worker locale l'ordine di aggregare i pesi
        python_worker_srv:send_message("AGGREGATE|" ++ Payload),
        {noreply, NewState#state{expected_nodes = 0}}; %% Reset così non innesca più finché non riparte
    true ->
        {noreply, NewState}
    end;

handle_cast({aggregated_result, Data}, State) ->
    %% Ricevuto il risultato del FedAvg dal worker python locale
    io:format("~c[35m🧠 [FED-AVG] Round completato! Nuovo Modello Globale: ~p~c[0m~n", [27, Data, 27]),
    {noreply, State};

handle_cast(_Msg, State) ->
    {noreply, State}.

handle_info(_Info, State) ->
    {noreply, State}.

terminate(_Reason, _State) ->
    ok.

code_change(_OldVsn, State, _Extra) ->
    {ok, State}.
