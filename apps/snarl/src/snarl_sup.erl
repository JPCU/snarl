-module(snarl_sup).

-behaviour(supervisor).

%% API
-export([start_link/0]).

%% Supervisor callbacks
-export([init/1]).

%% ===================================================================
%% API functions
%% ===================================================================

start_link() ->
    supervisor:start_link({local, ?MODULE}, ?MODULE, []).

%% ===================================================================
%% Supervisor callbacks
%% ===================================================================

init(_Args) ->
    GroupVMaster = {snarl_group_vnode_master,
                    {riak_core_vnode_master, start_link, [snarl_group_vnode]},
                    permanent, 5000, worker, [riak_core_vnode_master]},

    UserVMaster = {snarl_user_vnode_master,
                   {riak_core_vnode_master, start_link, [snarl_user_vnode]},
                   permanent, 5000, worker, [riak_core_vnode_master]},

    WriteFSMs = {snarl_entity_write_fsm_sup,
                 {snarl_entity_write_fsm_sup, start_link, []},
                 permanent, infinity, supervisor, [snarl_entity_write_fsm_sup]},

    TokenVMaster = {snarl_token_vnode_master,
                    {riak_core_vnode_master, start_link, [snarl_token_vnode]},
                    permanent, 5000, worker, [riak_core_vnode_master]},

    OrgVMaster = {snarl_org_vnode_master,
                  {riak_core_vnode_master, start_link, [snarl_org_vnode]},
                  permanent, 5000, worker, [riak_core_vnode_master]},

    CoverageFSMs = {snarl_entity_coverage_fsm_sup,
                    {snarl_entity_coverage_fsm_sup, start_link, []},
                    permanent, infinity, supervisor, [snarl_entity_coverage_fsm_sup]},

    ReadFSMs = {snarl_entity_read_fsm_sup,
                {snarl_entity_read_fsm_sup, start_link, []},
                permanent, infinity, supervisor, [snarl_entity_read_fsm_sup]},

    riak_core_entropy_info:create_table(),

    EntropyManagerUser =
        {snarl_user_entropy_manager,
         {riak_core_entropy_manager, start_link,
          [snarl_user, snarl_user_vnode]},
         permanent, 30000, worker, [riak_core_entropy_manager]},

    EntropyManagerGroup =
        {snarl_group_entropy_manager,
         {riak_core_entropy_manager, start_link,
          [snarl_group, snarl_group_vnode]},
         permanent, 30000, worker, [riak_core_entropy_manager]},

    EntropyManagerOrg =
        {snarl_org_entropy_manager,
         {riak_core_entropy_manager, start_link,
          [snarl_org, snarl_org_vnode]},
         permanent, 30000, worker, [riak_core_entropy_manager]},

    {ok,
     {{one_for_one, 5, 10},
      [{statman_server, {statman_server, start_link, [1000]},
        permanent, 5000, worker, []},
       {statman_aggregator, {statman_aggregator, start_link, []},
        permanent, 5000, worker, []},
       GroupVMaster, UserVMaster, TokenVMaster,
       OrgVMaster,
       EntropyManagerUser, EntropyManagerGroup, EntropyManagerOrg,
       ReadFSMs, WriteFSMs, CoverageFSMs]}}.
