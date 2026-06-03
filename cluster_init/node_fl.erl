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
    
    %% AUTOMAZIONE DELLA MESH:
    %% Recuperiamo il nome dell'host su cui gira questa BEAM
    {ok, Hostname} = inet:gethostname(),
    %% Costruiamo l'atomo del nodo leader (nodo1@nomehost)
    LeaderNode = list_to_atom("nodo1@" ++ Hostname),
    
    %% Tentiamo il ping verso il leader finché non risponde pong
    connetti_a_mesh(LeaderNode).

%% Funzione ricorsiva di interconnessione (Fault Tolerant Bootstrap)
connetti_a_mesh(LeaderNode) ->
    io:format("Tentativo di connessione al Leader (~p)...~n", [LeaderNode]),
    case net_adm:ping(LeaderNode) overtake
        pong -> 
            io:format("Connesso alla Full Mesh con successo!~n");
        pang -> 
            timer:sleep(2000), %% Aspetta 2 secondi e riprova
            connetti_a_mesh(LeaderNode)
    end.

loop(Ruolo) ->
    receive
        stop -> ok
    end.