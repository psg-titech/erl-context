-module(cross_complex).
-compile(export_all).

%% -include("runtime_gwr.hrl").
-include("runtime_gwrc.hrl").

%% Simple application for cross-context messages type (a)
main([_]) ->
    G = ?new_group([fun cross_complex:a1/1, fun cross_complex:a2/1, fun cross_complex:a3/1, fun cross_complex:aO/1]),
    O = {4, G},
    ?send(O, start),
    G.

context1() ->
    {'$context', {context1, {0,0,1}}}.

context2() ->
    {'$context', {context2, {0,0,2}}}.

aO(start) ->
    put(context, context1()), % [TODO] replace synchronous change_self_context
    ?send(?neighbor(1), first_from_observer),
    put(context, context2()),
    ?send(?neighbor(3), first_from_observer),
    ?send_delay(?neighbor(1), start_from_observer, 500),
    ?send_delay(?neighbor(3), start_from_observer, 500),
    % send cross-context message!
    put(context, context1()),
    ?send_delay(?neighbor(1), yheeaaaa, 2200).

a1(Msg) ->
    case Msg of
	first_from_observer ->
	    p("get first message from observer~n");
	start_from_observer ->
	    p("start~n"),
	    ?send(?neighbor(2), yhaa);
	yhaaa ->
	    p("get yhaaa from A2~n");
	yheeaaaa ->
	    p("get yheeaaaa(cross-context message)~n");
	_ ->
	    p("received unexpected ~p~n", [Msg])
    end.

a2(Msg) -> 
    case Msg of
	yhaa ->
	    p("get yhaa from A1~n"),
	    ?send_delay(?neighbor(1), yhaaa, 500);
	inst1 ->
	    p("get instruction of 1 and replying~n"),
	    ?send_delay(?neighbor(3), inst1_reply, 600);
	inst2 ->
	    p("get instruction of 2~n");
	_ ->
	    p("received unexpected ~p~n", [Msg])
    end.

a3(Msg) -> 
    case Msg of
	first_from_observer -> 
	    p("get first message from observer~n");
	start_from_observer ->
	    p("start send two instrunction to A2~n"),
	    ?send_delay(?neighbor(2), inst1, 520),
	    ?send_delay(?neighbor(2), inst2, 1020);
	inst1_reply ->
	    p("get reply of instruction of 1~n")
    end.

p(S) ->
    p(S, []).

p(S, Ls) ->
    {N, _} = ?self(),
    io:format(string:concat(io_lib:format("A~p: ",[N]), S), Ls).
