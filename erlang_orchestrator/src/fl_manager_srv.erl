-module(fl_manager_srv).
-behaviour(gen_server).

-export([start_link/0, start_round/0]).
-export([init/1, handle_call/3, handle_cast/2, handle_info/2, terminate/2, code_change/3]).

-record(state, {leader_node = undefined, accumulated_weights = [], expected_nodes = 0, timer_ref = undefined}).

start_link() ->
    gen_server:start_link({local, ?MODULE}, ?MODULE, [], []).

start_round() ->
    gen_server:cast(?MODULE, start_round).

init([]) ->
    {ok, #state{}}.

handle_call(_Request, _From, State) ->
    {reply, ok, State}.

handle_cast(start_round, State) ->
    Expected = length(nodes()) + 1,
    lists:foreach(fun(Node) ->
        gen_server:cast({?MODULE, Node}, {train_command, node()})
    end, nodes() ++ [node()]),
    TimerRef = erlang:send_after(5000, self(), round_timeout),
    {noreply, State#state{accumulated_weights = [], expected_nodes = Expected, timer_ref = TimerRef}};

handle_cast({train_command, LeaderNode}, State) ->
    python_worker_srv:send_message("TRAIN"),
    {noreply, State#state{leader_node = LeaderNode}};

handle_cast({python_result, Data}, State = #state{leader_node = LeaderNode}) ->
    if LeaderNode =/= undefined ->
        gen_server:cast({?MODULE, LeaderNode}, {weights_payload, node(), Data});
    true ->
        io:format("⚠️ [FL-MANAGER] Nessun leader settato, ignoro il risultato.~n")
    end,
    {noreply, State};

handle_cast({weights_payload, FromNode, Data}, State = #state{accumulated_weights = Acc, expected_nodes = Expected, timer_ref = TimerRef}) ->
    io:format("~c[32m📥 [FL-MANAGER] Ricevuti pesi dal nodo ~p: ~p~c[0m~n", [27, FromNode, Data, 27]),
    NewAcc = [Data | Acc],
    NewState = State#state{accumulated_weights = NewAcc},
    if length(NewAcc) >= Expected andalso Expected > 0 ->
        if TimerRef =/= undefined -> erlang:cancel_timer(TimerRef); true -> ok end,
        Payload = "[" ++ string:join(NewAcc, ",") ++ "]",
        python_worker_srv:send_message("AGGREGATE|" ++ Payload),
        {noreply, NewState#state{expected_nodes = 0, timer_ref = undefined}};
    true ->
        {noreply, NewState}
    end;

handle_cast({aggregated_result, Data}, State) ->
    io:format("~c[35m🧠 [FED-AVG] Round completato! Nuovo Modello Globale: ~p~c[0m~n", [27, Data, 27]),
    {noreply, State};

handle_cast(_Msg, State) ->
    {noreply, State}.

handle_info(round_timeout, State = #state{accumulated_weights = Acc, expected_nodes = Expected}) ->
    if Expected > 0 andalso length(Acc) > 0 ->
        io:format("~c[33m⚠️ [FL-MANAGER] Timeout! Aggregazione parziale d'emergenza con ~p nodi su ~p.~c[0m~n", [27, length(Acc), Expected, 27]),
        Payload = "[" ++ string:join(Acc, ",") ++ "]",
        python_worker_srv:send_message("AGGREGATE|" ++ Payload);
       Expected > 0 andalso length(Acc) == 0 ->
        io:format("~c[31m❌ [FL-MANAGER] Timeout! Nessun nodo ha risposto. Round fallito.~c[0m~n", [27, 27]);
       true ->
        ok
    end,
    {noreply, State#state{expected_nodes = 0, accumulated_weights = [], timer_ref = undefined}};

handle_info(_Info, State) ->
    {noreply, State}.

terminate(_Reason, _State) ->
    ok.

code_change(_OldVsn, State, _Extra) ->
    {ok, State}.