-module(runtime_ctx).
-export([newCtx/1, send/2, send/3, new/3]).

%%%=========================================================================
%%%  API
%%%=========================================================================

newCtx(Fs) ->
    N = length(Fs),
    core:new(metaCtx(replicate(N, []), Fs, replicate(N, dormant), replicate(N, context:default()), core:new(fun exec/1))).

new(F, {N, MetaG}, Ctx) ->
    MetaG ! {new, F, self(), Ctx},
    % becomeの返り値を利用してしまっている
    core:become(fun(X) -> X end).

send(Dest, Msg) ->
    runtime:send(Dest, Msg).

% Extension
send(Dest, Msg, Ctx) ->
    case Dest of 
	{N, _Dest} -> _Dest ! {mesg, {N, Msg, Ctx}};
	_ -> Dest ! {mesg, Msg}
    end.

new(F, {N, MetaCtx}) ->
    MetaCtx ! {new, F, self()},
    % becomeの返り値を利用してしまっている
    core:become(fun(X) -> X end).

%%%=========================================================================
%%%  Internal Function
%%%=========================================================================

exec(Arg) ->
    %% io:format("engine received ~p.~n",[Arg]),
    case Arg of
	{apply, F, M, From} ->
	    apply(F, [M, From]),
	    From ! 'end',
	    core:become(fun exec/1);
	{apply, F, M, From, N} ->
	    apply(F, [M, {N, From}]),
	    From ! {'end', N},
	    core:become(fun exec/1);
	% Extension
	{apply, F, M, From, Ctx, N} ->
	    apply(F, [M, {N, From}, Ctx]),
	    From ! {'end', N},
	    core:become(fun exec/1)
    end.

metaCtx(Qs, Fs, Ss, Cs, E) ->
    fun (RawM) ->
	    %% io:format("meatCtx received ~p.~n  state: ~p~n",[RawM, {Qs, Fs, Ss, Cs}]),
	    case RawM of
		{mesg, {N, M}} ->
		    NthSs = nth(N, Ss),
		    case NthSs of
			dormant ->
			    self() ! {'begin', N},
			    core:become(metaCtx(substNth(N, nth(N,Qs)++[M], Qs), Fs, substNth(N, active, Ss), Cs, E));
			active ->
			    core:become(metaCtx(substNth(N, nth(N,Qs)++[M], Qs), Fs, substNth(N, active, Ss), Cs, E))
		    end;
		% Extension
		{mesg, {N, M, {'$context', _} = C}} ->
		    NthSs = nth(N, Ss),
		    case NthSs of
			dormant ->
			    self() ! {'begin', N},
			    core:become(metaCtx(substNth(N, nth(N,Qs)++[{M, C}], Qs), Fs, substNth(N, active, Ss), Cs, E));
			active ->
			    core:become(metaCtx(substNth(N, nth(N,Qs)++[{M, C}], Qs), Fs, substNth(N, active, Ss), Cs, E))
		    end;
		{'begin', N} ->
		    case nth(N, Qs) of
			% Extension
			[{{'$context', _} = C, X}|_Q] ->
			    case context:compare(nth(N, Cs), C) == newer and lists:all(fun({_, _C}) -> context:compare(C, _C) == older end, _Q) of 
				true  -> core:become(metaCtx(substNth(N, _Q, Qs), Fs, Ss, substNth(N, C, Cs),E));
				false -> core:become(metaCtx(substNth(N, _Q++[{C, X}], Qs), Fs, Ss, Cs,E))
			    end;
			% Extension
			[{M, {'$context', _} = C}|_Q] ->
			    E ! {apply, nth(N, Fs), M, self(), nth(N, Cs), N},
			    case context:compare(nth(N, Cs), C) of
				newer ->
				    core:become(metaCtx(substNth(N, _Q, Qs), Fs, Ss, substNth(N, C, Cs),E));
				_ ->
				    core:become(metaCtx(substNth(N, _Q, Qs), Fs, Ss, Cs,E))
			    end;
			% 
			[M|_Q] ->
			    E ! {apply, nth(N, Fs), M, self(), nth(N, Cs), N},
			    core:become(metaCtx(substNth(N, _Q, Qs), Fs, Ss, Cs, E))
			    
		    end;
		{'end', N} ->
		    case nth(N, Qs) of
			[] -> core:become(metaCtx(Qs, Fs, substNth(N, dormant, Ss), Cs, E));
			[_|_] ->
			    self() ! {'begin', N},
			    core:become(metaCtx(Qs, Fs, Ss, Cs, E))
		    end;
		{new, F, From} ->
		    N = length(Qs) + 1,
		    From ! {N, self()},
		    core:become(metaCtx(Qs++[[]], Fs++[F], Ss++[dormant], Cs++[context:default()], E));
		% Extension
		{new, F, From, Ctx} ->
		    N = length(Qs) + 1,
		    From ! {N, self()},
		    core:become(metaCtx(Qs++[[]], Fs++[F], Ss++[dormant], Cs++[Ctx], E));
		inspect -> % for debug
		    erlang:display({Qs, Fs, Ss, Cs}),
		    core:become(metaCtx(Qs, Fs, Ss, Cs, E))
	    end
    end.

%% ----------- Utils -----------

nth(N, [H|T]) ->
    case N of
	1 -> H;
	N when N > 1 -> nth(N-1, T)
    end.

substNth(N, V, Ls) ->
    case {Ls, N} of
	{[_|T], 1} -> [V|T];
	{[H|T], N} when N > 1 -> [H|substNth(N-1, V, T)]
    end.

replicate(N, V) ->
    case N of
	0 -> [];
	N when N > 0 -> [V|replicate(N-1, V)]
    end.
