-module(fl_manager_tests).
-include_lib("eunit/include/eunit.hrl").

%% 1. MOCK DELLO STATO
-record(state, {leader_node = undefined, accumulated_weights = [], expected_nodes = 0, timer_ref = undefined}).

%% 2. TEST CASES

init_test() ->
    {ok, State} = fl_manager_srv:init([]),
    ?assertEqual({state, undefined, [], 0, undefined}, State).

start_round_test() ->
    InitialState = #state{},
    {noreply, NewState} = fl_manager_srv:handle_cast(start_round, InitialState),
    ?assertEqual(1, NewState#state.expected_nodes),
    ?assertNotEqual(undefined, NewState#state.timer_ref).

weights_accumulation_test() ->
    %% MOCK: Creiamo un processo fittizio che finge di essere python_worker_srv
    %% e risponde "ok" a qualsiasi gen_server:call, per non far fallire il manager.
    MockPid = spawn(fun Loop() -> 
        receive 
            {'$gen_call', From, _Msg} -> 
                gen_server:reply(From, ok), 
                Loop();
            _ -> 
                Loop() 
        end 
    end),
    register(python_worker_srv, MockPid),

    %% Eseguiamo il test
    State = #state{expected_nodes = 2, accumulated_weights = ["[0.1, 0.2]"]},
    {noreply, NewState} = fl_manager_srv:handle_cast({weights_payload, 'nodo2@test', "[0.3, 0.4]"}, State),
    
    %% Verifiche
    ?assertEqual(0, NewState#state.expected_nodes),
    ?assertEqual(undefined, NewState#state.timer_ref),

    %% PULIZIA: Rimuoviamo il finto processo
    unregister(python_worker_srv),
    exit(MockPid, kill).

timeout_failure_test() ->
    State = #state{expected_nodes = 3, accumulated_weights = []},
    {noreply, NewState} = fl_manager_srv:handle_info(round_timeout, State),
    ?assertEqual(0, NewState#state.expected_nodes),
    ?assertEqual([], NewState#state.accumulated_weights).