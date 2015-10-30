%%%-------------------------------------------------------------------
%%% @author wanghaohao
%%% @copyright (C) 2015, <COMPANY>
%%% @doc
%%%
%%% @end
%%% Created : 30. 十月 2015 16:52
%%%-------------------------------------------------------------------
-module(default_behaviour).
-author("wanghaohao").

%% API
-export([parse_transform/2]).
-compile(export_all).

-define(GEN_SERVER_EXPORT, [{handle_call, 3},
    {handle_cast, 2},
    {handle_info, 2},
    {code_change, 3},
    {terminate, 2}]).

-define(ACTIONS, [export, default_fun]).

parse_transform(Forms, _Opts) ->
    NewForms = behaviour(Forms),
%%     io:format("~p~n", [NewForms]),
    NewForms.


behaviour(Forms) ->
    case lists:keyfind(behaviour, 3, Forms) of
        {attribute, _Line, _, BehaviourName} ->
            lists:foldl(fun(Action, Acc) ->
                ?MODULE:Action(BehaviourName, Acc)
            end, Forms, ?ACTIONS);
        _ ->
            Forms
    end.

export(BehaviourName, Forms) ->
    ?MODULE:BehaviourName(export, Forms).

default_fun(BehaviourName, Forms) ->
    ?MODULE:BehaviourName(default_fun, Forms).

gen_server(export, Forms) ->
    {ok, Exports, NewForms} = get_all_exports(Forms),
    NewExports = lists:map(fun(E)->
        {attribute, Line, export, ExportList} = E,
        {attribute, Line, export, ExportList -- ?GEN_SERVER_EXPORT}
    end, Exports),
    insert_export([{attribute, 0, export, ?GEN_SERVER_EXPORT}|NewExports], NewForms);

gen_server(default_fun, Forms) ->
    FunForms = lists:foldr(fun({Fun, _},Acc) ->
        case lists:keyfind(Fun, 3, Forms) of
            false ->
                [gen_server_fun_form(Fun)|Acc];
            _ ->
                Acc
        end
    end, [], ?GEN_SERVER_EXPORT),
%%     Forms ++ lists:flatten(FunForms);
    [Eof|Rforms] = lists:reverse(Forms),
    lists:reverse(lists:concat([[Eof], lists:flatten(FunForms), Rforms]));



gen_server(_, Forms) ->
    Forms.

gen_server_fun_form(Fun) ->
    Str = gen_server_fun_str(Fun),
    if
        Str =:= undefined ->
            [];
        true ->
            {ok, S, _L} = erl_scan:string(Str),
            {ok, Forms} = erl_parse:parse_form(S),
            Forms
    end.

gen_server_fun_str(handle_call) ->
    "handle_call(_Req, _From, State)-> {reply, ok, State}.";
gen_server_fun_str(handle_cast) ->
    "handle_cast(_Msg, State) -> {noreply, State}.";
gen_server_fun_str(handle_info) ->
    "handle_info(_Info, State) -> {noreply, State}.";
gen_server_fun_str(code_change) ->
    "code_change(_Oldvsn, State, _Extra) -> {ok, State}.";
gen_server_fun_str(terminate) ->
    "terminate(_Reason, _State) -> ok.";
gen_server_fun_str(_) ->
    undefined.

get_all_exports(Forms) ->
    get_all_exports(true, [], Forms).

get_all_exports(true, Exports, Forms) ->
    case lists:keytake(export, 3, Forms) of
        false ->
            get_all_exports(false, Exports, Forms);
        {value, Tuple, NewForms} ->
            get_all_exports(true, [Tuple | Exports], NewForms)
    end;
get_all_exports(false, Exports, Forms) ->
    {ok, Exports, Forms}.

insert_export(Exports, Forms) ->
    insert_export(Exports, Forms, []).

insert_export(Export, [Form|Forms], Head) ->
    case Form of
        {attribute, _L, behaviour, _} ->
            lists:concat([lists:reverse(Head), Export, Forms]);
        _ ->
            insert_export(Export, Forms, [Form|Head])
    end;
insert_export(Export, [], Head) ->
    lists:reverse(lists:concat([Export, Head])).
