-module(snarl_org).
-include("snarl.hrl").
-include_lib("riak_core/include/riak_core_vnode.hrl").

-export([
         ping/0,
         list/0,
         get/1,
         get_/1,
         lookup/1,
         add/1,
         delete/1,
         set/2,
         set/3,
         create/2,
         gcable/1,
         import/2,
         gc/2
        ]).

-ignore_xref([
         ping/0,
         list/0,
         get/1,
         get_/1,
         lookup/1,
         add/1,
         delete/1,
         set/2,
         set/3,
         create/2,
         gcable/1,
         import/2,
         gc/2
        ]).

-ignore_xref([ping/0, create/2]).

-define(TIMEOUT, 5000).

%% Public API

%% @doc Pings a random vnode to make sure communication is functional
ping() ->
    DocIdx = riak_core_util:chash_key({<<"ping">>, term_to_binary(now())}),
    PrefList = riak_core_apl:get_primary_apl(DocIdx, 1, snarl_org),
    [{IndexNode, _Type}] = PrefList,
    riak_core_vnode_master:sync_spawn_command(IndexNode, ping, snarl_org_vnode_master).

import(Org, Data) ->
    do_write(Org, import, Data).

-spec lookup(OrgName::binary()) ->
                    not_found |
                    {error, timeout} |
                    {ok, Org::fifo:org()}.

lookup(OrgName) ->
    {ok, Res} = snarl_entity_coverage_fsm:start(
                  {snarl_org_vnode, snarl_org},
                  lookup, OrgName),
    R0 = lists:foldl(fun (not_found, Acc) ->
                             Acc;
                         (R, _) ->
                             {ok, R}
                     end, not_found, Res),
    case R0 of
        {ok, UUID} ->
            snarl_org:get(UUID);
        R ->
            R
    end.

-spec gcable(Org::fifo:org_id()) ->
                    not_found |
                    {error, timeout} |
                    {ok, [term()]}.
gcable(Org) ->
    case get_(Org) of
        {ok, OrgObj} ->
            {ok, snarl_org_state:gcable(OrgObj)};
        R  ->
            R
    end.

-spec gc(Org::fifo:org_id(),
         GCable::term()) ->
                not_found |
                {error, timeout} |
                ok.
gc(Org, GCable) ->
    case get_(Org) of
        {ok, OrgObj1} ->
            do_write(Org, gc, GCable),
            {ok, OrgObj2} = get_(Org),
            {ok, byte_size(term_to_binary(OrgObj1)) -
                 byte_size(term_to_binary(OrgObj2))};
        R ->
            R
    end.


-spec get(Org::fifo:org_id()) ->
                 not_found |
                 {error, timeout} |
                 {ok, Org::fifo:org()}.
get(Org) ->
    case get_(Org) of
        {ok, OrgObj} ->
            {ok, snarl_org_state:to_json(OrgObj)};
        R  ->
            R
    end.

-spec get_(Org::fifo:org_id()) ->
                 not_found |
                 {error, timeout} |
                 {ok, Org::#?ORG{}}.
get_(Org) ->
    case snarl_entity_read_fsm:start(
           {snarl_org_vnode, snarl_org},
           get, Org
          ) of
        {ok, not_found} ->
            not_found;
        R ->
            R
    end.

-spec list() -> {ok, [fifo:org_id()]} |
                not_found |
                {error, timeout}.

list() ->
    snarl_entity_coverage_fsm:start(
      {snarl_org_vnode, snarl_org},
      list
     ).

-spec add(Org::binary()) ->
                 {ok, UUID::fifo:org_id()} |
                 douplicate |
                 {error, timeout}.

add(Org) ->
    UUID = list_to_binary(uuid:to_string(uuid:uuid4())),
    create(UUID, Org).

create(UUID, Org) ->
    case snarl_org:lookup(Org) of
        not_found ->
            ok = do_write(UUID, add, Org),
            {ok, UUID};
        {ok, _OrgObj} ->
            duplicate
    end.

-spec delete(Org::fifo:org_id()) ->
                    ok |
                    not_found|
                    {error, timeout}.

delete(Org) ->
    do_write(Org, delete).

-spec set(Org::fifo:org_id(), Attirbute::fifo:key(), Value::fifo:value()) ->
                 not_found |
                 {error, timeout} |
                 ok.
set(Org, Attribute, Value) ->
    set(Org, [{Attribute, Value}]).

-spec set(Org::fifo:org_id(), Attirbutes::fifo:attr_list()) ->
                 not_found |
                 {error, timeout} |
                 ok.
set(Org, Attributes) ->
    do_write(Org, set, Attributes).


%%%===================================================================
%%% Internal Functions
%%%===================================================================

do_write(Org, Op) ->
    snarl_entity_write_fsm:write({snarl_org_vnode, snarl_org}, Org, Op).

do_write(Org, Op, Val) ->
    snarl_entity_write_fsm:write({snarl_org_vnode, snarl_org}, Org, Op, Val).