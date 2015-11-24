#!/usr/bin/env escript
%% first attempt at erlang, probably not the best way to do things
main(_) ->
    io:format("Basic collatz fun - recursive erlang function~n", []),
    r(15).

r(N) ->
    io:format("~B~n", [N]),
    if N == 1 ->
            1;
    true ->
           if (N rem 2)==1 ->
                  r(N*3+1);
           true ->
                  r(N div 2)
           end
    end.

