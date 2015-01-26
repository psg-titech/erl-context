-define(send(Dest, Msg), runtime:send(Dest, Msg)).
-define(new(F), runtime:new(F)).
-define(new_group(Fs), runtime:new_group(Fs)).
-define(change_behavior(F, Self), runtime:change_behavior(F, Self)).
-define(self(), runtime:usr_self()).
-define(neighbor(N), runtime:neighbor(N)).

% for experiments
-define(send_delay(Dest, Msg, Delay), runtime:send_delay(Dest, Msg, Delay)).
