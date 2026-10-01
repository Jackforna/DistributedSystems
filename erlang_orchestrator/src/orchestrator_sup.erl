%%% Supervisore di root (Supervision Tree) dell'applicazione Erlang/OTP.
%%% Garantisce la Fault Isolation avviando e monitorando i microservizi critici del nodo.

-module(orchestrator_sup).
-behaviour(supervisor).

-export([start_link/0]).
-export([init/1]).

%% Avvio del supervisore registrandolo localmente con il nome del modulo
start_link() ->
    supervisor:start_link({local, ?MODULE}, ?MODULE, []).

%% Inizializzazione delle policy di riavvio e l'elenco dei processi figli (worker)
init([]) ->

    %% Strategia one_for_one: se un figlio muore, riavvia solo lui. 
    %% Garantisce l'isolamento dei fallimenti (Fault Isolation).
    SupFlags = #{strategy => one_for_one,
                 intensity => 1,
                 period => 5},

    %% L'ordine nella lista definisce la sequenza di avvio dei processi.
    ChildSpecs = [

        %% 1. Gestisce l'Auto-Discovery e chiude la topologia Full-Mesh
        #{id => cluster_manager_srv,
          start => {cluster_manager_srv, start_link, []},
          restart => permanent,
          shutdown => 5000,
          type => worker,
          modules => [cluster_manager_srv]},

        %% 2. Bridge asincrono verso il processo OS Python (Data Plane)
        #{id => bully_srv,
          start => {bully_srv, start_link, []},
          restart => permanent,
          shutdown => 5000,
          type => worker,
          modules => [bully_srv]},
        
        %% 3. Esecuzione del Bully Algorithm per l'elezione decentralizzata
        #{id => python_worker_srv,
          start => {python_worker_srv, start_link, []},
          restart => permanent,
          shutdown => 5000,
          type => worker,
          modules => [python_worker_srv]},
        
        %% 4. Orchestraazione dei round FedAvg e gestione  dei timeout (Stragglers)
        #{id => fl_manager_srv,
          start => {fl_manager_srv, start_link, []},
          restart => permanent,
          shutdown => 5000,
          type => worker,
          modules => [fl_manager_srv]}
    ],
    {ok, {SupFlags, ChildSpecs}}.
