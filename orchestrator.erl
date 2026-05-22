-module(orchestrator).
-export([start/0, stop/0, calcola/1]).

start() ->
    Port = open_port({spawn, "python3 worker.py"}, [{line, 1024}]),
    register(python_worker, Port),
    io:format("✅ Orchestratore Erlang avviato. Worker Python connesso.~n").

stop() ->
    % Inviamo il segnale di chiusura. Erlang chiude la porta e deregistra il nome in automatico.
    python_worker ! {self(), close},
    io:format("🛑 Worker Python disconnesso.~n").

calcola(Numero) ->
    Payload = io_lib:format("~w~n", [Numero]),
    python_worker ! {self(), {command, Payload}},
    
    receive
        % Accettiamo la risposta da QUALSIASI port (_Port invece di python_worker)
        {_Port, {data, {eol, Risposta}}} ->
            io:format("📩 Erlang ha ricevuto: ~s~n", [Risposta]);
        
        % Se arriva qualcosa di strano, ora ce lo facciamo stampare (~p)
        Altro ->
            io:format("⚠️ Risposta inaspettata: ~p~n", [Altro])
    after 5000 ->
        io:format("❌ TIMEOUT: Il worker Python non ha risposto.~n")
    end.