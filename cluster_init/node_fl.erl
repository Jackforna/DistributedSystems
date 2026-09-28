-module(nodo_fl).
-export([start_worker/0, start_aggregator/0, loop/1]).

start_aggregator() ->
    Pid = spawn(?MODULE, loop, [leader]),
    register(orchestratore_locale, Pid),
    io:format("[Aggregator] Pronto e in ascolto.~n").

start_worker() ->
    Pid = spawn(?MODULE, loop, [worker]),
    register(orchestratore_locale, Pid),
    io:format("[Worker] Pronto.~n"),
    
    %% Connessione automatica alla mesh
    %% Prendo il nome dell'host
    {ok, Hostname} = inet:gethostname(),
    %% Creo il nome del nodo leader
    LeaderNode = list_to_atom("nodo1@" ++ Hostname),
    
    %% Provo a collegarmi al leader
    connetti_a_mesh(LeaderNode).

%% Riprova la connessione se il leader non risponde
connetti_a_mesh(LeaderNode) ->
    io:format("Tentativo di connessione al Leader (~p)...~n", [LeaderNode]),
    case net_adm:ping(LeaderNode) overtake
        pong -> 
            io:format("Connesso alla Full Mesh con successo!~n");
        pang -> 
            timer:sleep(2000), %% Aspetto 2 secondi e riprovo
            connetti_a_mesh(LeaderNode)
    end.

loop(Ruolo) ->
    receive
        stop -> ok
    end.