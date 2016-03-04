-module(om).
-description('Om Intermediate Compiler').
-behaviour(supervisor).
-behaviour(application).
-export([init/1, start/2, stop/1]).
-compile(export_all).

% providing functions

main(A)     -> mad:main(A).
start()     -> start(normal,[]).
start(_,_)  -> supervisor:start_link({local,om},om,[]).
stop(_)     -> ok.
extract()   -> om_extract:scan().
modes()     -> ["erased","girard","hurkens","normal","setoids"].
priv(Mode)  -> lists:concat(["priv/",Mode]).
mode(S)     -> application:set_env(om,mode,S).
type(S)     -> om_type:getType(om:term(S)).
mode()      -> application:get_env(om,mode,"erased").
init([])    -> mode("normal"), {ok, {{one_for_one, 5, 10}, []}}.
term(F)     -> T = string:tokens(F,"/"), P = string:join(rev(tl(rev(T))),"/"), term(P,lists:last(T)).
term(P,F)   -> case parse(P,F) of {[],error} -> parse([],F); {[],[]} -> {[],error}; {[],[X]} -> X end.
name(M,P,F) -> string:join(["priv",mode(),case P of [] -> F; _ -> P ++ "/" ++ F end],"/").
parse(P,F)  -> try om_parse:expr(P,read(P,name(mode(),P,F)),[]) catch E:R ->
               io:format("ERROR: file: ~tp~n~tp~n",[erlang:get_stacktrace(),R]),
               {[],error} end.
str(P,F)    -> om_tok:tokens(P,unicode:characters_to_binary(F),0,{1,[]},[]).
a(F)        -> {[],[X]} = om_parse:expr([],om_tok:tokens([],unicode:characters_to_binary(F),0,{1,[]},[]),[]), X.
read(P,F)   -> om_tok:tokens(P,file(F),0,{1,[]},[]).
all()       -> lists:flatten([ begin om:mode(M), om:scan() end || M <- modes() ]).
syscard()   -> [ {F} || F <- filelib:wildcard(name(mode(),"**","*")), filelib:is_dir(F) /= true ].
wildcard()  -> lists:flatten([ {A} || {A,B} <- ets:tab2list(filesystem),
               lists:sublist(A,length(om:priv(mode()))) == om:priv(mode()) ]).

scan()      -> Res = [ {element(1,show(F))/=[],F} || {F} <- lists:umerge(wildcard(),syscard()) ],
               error("Tests: ~tp~n",[Res]),
               Passed = lists:all(fun({X,B}) -> X == true end, Res),
               case Passed of
                    true -> error("PASSED~n",[]);
                    false -> error("FAILED~n",[]) end,
               Res.
show(F)     -> T = string:substr(string:tokens(F,"/"),3), Type = term(string:join(T,"/")),
               error("~n===[ File: ~ts ]==========~nCat: ~tsTerm: ~100tp~n",[F,file(F),size(term_to_binary(Type))]), Type.


% relying functions

rev(X)       -> lists:reverse(X).
flat(X)      -> lists:flatten(X).
tokens(X,Y)  -> string:tokens(X,Y).
print(S,A)   -> io_lib:format(S,A).
error(S,A)   -> io:format(S,A).
atom(X)      -> list_to_atom(X).
last(X)      -> lists:last(X).


file(F) -> case file:read_file(F) of
                {ok,Bin} -> Bin;
                {error,_} -> mad(F) end.

mad(F)  -> case mad_repl:load_file(F) of
                {ok,Bin} -> Bin;
                {error,_} -> <<>> end.
