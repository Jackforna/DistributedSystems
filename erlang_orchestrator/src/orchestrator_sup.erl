-module(orchestrator_sup).
-behaviour(supervisor).

-export([start_link/0]).
-export([init/1]).

start_link() ->
    supervisor:start_link({local, ?MODULE}, ?MODULE, []).

init([]) ->
    SupFlags = #{strategy => one_for_one,
                 intensity => 1,
                 period => 5},
    ChildSpecs = [
        #{id => cluster_manager_srv,
          start => {cluster_manager_srv, start_link, []},
          restart => permanent,
          shutdown => 5000,
          type => worker,
          modules => [cluster_manager_srv]},
        #{id => bully_srv,
          start => {bully_srv, start_link, []},
          restart => permanent,
          shutdown => 5000,
          type => worker,
          modules => [bully_srv]},
        #{id => python_worker_srv,
          start => {python_worker_srv, start_link, []},
          restart => permanent,
          shutdown => 5000,
          type => worker,
          modules => [python_worker_srv]},
        #{id => fl_manager_srv,
          start => {fl_manager_srv, start_link, []},
          restart => permanent,
          shutdown => 5000,
          type => worker,
          modules => [fl_manager_srv]}
    ],
    {ok, {SupFlags, ChildSpecs}}.
