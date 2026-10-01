%%% Entry point dell'applicazione OTP per il nodo Erlang.
%%% Viene invocato dalla VM all'avvio per far partire il supervisore principale (orchestrator_sup).

-module(erlang_orchestrator_app).
-behaviour(application).

-export([start/2, stop/1]).

start(_StartType, _StartArgs) ->
    orchestrator_sup:start_link().

stop(_State) ->
    ok.
