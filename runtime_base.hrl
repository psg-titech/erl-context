-define(send(Dest, Msg), runtime_base:send(Dest, Msg)).
-define(new(F), runtime_base:new(F)).
-define(self(), erlang:self()).
-define(become(F), runtime_base:become(F)).