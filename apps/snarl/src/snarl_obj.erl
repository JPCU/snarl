%% @doc A suite of functions that operate on the algebraic data type
%% `snarl_obj'.
%%
%% TODO Possibly move type/record defs in there and use accessor funs
%% and opaque types.
%%
%% Taken form https://github.com/Licenser/try-try-try/blob/master/2011/riak-core-conflict-resolution/rts/src/rts_obj.erl

-module(snarl_obj).
-export([ancestors/1, children/1, equal/1, equal/2, merge/2, unique/1,
         update/3]).
-export([val/1, vclock/1]).

-ignore_xref([
              ancestors/1,
              equal/1,
              unique/1,
              vclock/1
             ]).

-include("snarl.hrl").

%% @pure
%%
%% @doc Given a list of `snarl_obj()' return a list of all the
%% ancestors.  Ancestors are objects that all the other objects in the
%% list have descent from.
-spec ancestors([snarl_obj()]) -> [snarl_obj()].
ancestors(Objs0) ->
    Objs = [O || O <- Objs0, O /= not_found],
    As = [[O2 || O2 <- Objs,
                 ancestor(O2#snarl_obj.vclock,
                          O1#snarl_obj.vclock)] || O1 <- Objs],
    unique(lists:flatten(As)).

%% @pure
%%
%% @doc Predicate to determine if `Va' is ancestor of `Vb'.
-spec ancestor(vclock:vclock(), vclock:vclock()) -> boolean().
ancestor(Va, Vb) ->
    vclock:descends(Vb, Va) andalso (vclock:descends(Va, Vb) == false).

%% @pure
%%
%% @doc Given a list of `snarl_obj()' return a list of the children
%% objects.  Children are the descendants of all others objects.
children(Objs) ->
    unique(Objs) -- ancestors(Objs).

%% @pure
%%
%% @doc Predeicate to determine if `ObjA' and `ObjB' are equal.
-spec equal(ObjA::snarl_obj(), ObjB::snarl_obj()) -> boolean().
equal(#snarl_obj{vclock=A}, #snarl_obj{vclock=B}) -> vclock:equal(A,B);
equal(not_found, not_found) -> true;
equal(_, _) -> false.

%% @pure
%%
%% @doc Closure around `equal/2' for use with HOFs (damn verbose
%% Erlang).
-spec equal(ObjA::snarl_obj()) -> fun((ObjB::snarl_obj()) -> boolean()).
equal(ObjA) ->
    fun(ObjB) -> equal(ObjA, ObjB) end.

%% @pure
%%
%% @doc Merge the list of `Objs', calling the appropriate reconcile
%% fun if there are siblings.
-spec merge(atom(),[snarl_obj()]) -> snarl_obj().
merge(FSM, [not_found|_]=Objs) ->
    P = fun(X) -> X == not_found end,
    case lists:all(P, Objs) of
        true -> not_found;
        false -> merge(FSM, lists:dropwhile(P, Objs))
    end;

merge(FSM, [#snarl_obj{}|_]=Objs) ->
    case snarl_obj:children(Objs) of
        [] -> not_found;
        [Child] -> Child;
        Chldrn ->
            Val = FSM:reconcile(lists:map(fun val/1, Chldrn)),
            MergedVC = vclock:merge(lists:map(fun vclock/1, Chldrn)),
            #snarl_obj{val=Val, vclock=MergedVC}
    end.

%% @pure
%%
%% @doc Given a list of `Objs' return the list of uniques.
-spec unique([snarl_obj()]) -> [snarl_obj()].
unique(Objs) ->
    F = fun(not_found, Acc) ->
                Acc;
           (Obj, Acc) ->
                case lists:any(equal(Obj), Acc) of
                    true -> Acc;
                    false -> [Obj|Acc]
                end
        end,
    lists:foldl(F, [], Objs).

%% @pure
%%
%% @doc Given a `Val' update the `Obj'.  The `Updater' is the name of
%% the entity performing the update.
-spec update(val(), node(), snarl_obj()) -> snarl_obj().
update(Val, Updater, #snarl_obj{vclock=VClock0}=Obj0) ->
    VClock = vclock:increment(Updater, VClock0),
    Obj0#snarl_obj{val=Val, vclock=VClock}.

-spec val(snarl_obj()) -> any().
val(#snarl_obj{val=Val}) -> Val;
val(not_found) -> not_found.

%% @pure
%%
%% @doc Given a vclock type `Obj' retrieve the vclock.
-spec vclock(snarl_obj()) -> vclock:vclock().
vclock(#snarl_obj{vclock=VC}) -> VC.
