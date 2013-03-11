-module(elli_tcp_test).
-include_lib("eunit/include/eunit.hrl").
-include("elli.hrl").

connect_test_() ->
    {setup, fun setup_elli_http_server/0, fun teardown/1,
     [?_test(connect())]
    }.

connect_ssl_test_() ->
    {setup, fun setup_elli_https_server/0, fun teardown/1,
     [?_test(connect_ssl())]
    }.

listen_test() ->
	%% Normal socket.
	{ok, Socket} = elli_tcp:listen(3003, [{reuseaddr, true}]),
	?assertEqual(plain, elli_tcp:type(Socket)),
	?assertMatch({ok, 3003}, elli_tcp:port(Socket)),
	elli_tcp:close(Socket),

	%% Ssl socket
	{ok, SslSocket} = elli_tcp:listen({ssl, 3003}, [{reuseaddr, true}]),
	?assertEqual({ok, 3003}, elli_tcp:port(SslSocket)),
	?assertEqual(ssl, elli_tcp:type(SslSocket)).

connect_ssl() ->
	{ok, Socket} = elli_tcp:connect("localhost", {ssl, 3003},
		[{active, false}, binary], 2000),
	?assertEqual({ok, {{127,0,0,1}, 3003}}, elli_tcp:peername(Socket)),
	?assertMatch({ok, _Port}, elli_tcp:port(Socket)),
	Req = <<"GET /hello HTTP/1.1\r\nConnection: close\r\n\r\n">>,
    ?assertEqual(ok, elli_tcp:send(Socket, Req)),
    ?assertEqual({ok, <<"HTTP/1.1 200 OK">>}, 
    	elli_tcp:recv(Socket, 15, 10000)),
	ok.

connect() ->
	{ok, Socket} = elli_tcp:connect("localhost", 3003, 
		[{active, false}, binary], 2000),
	?assertEqual({ok, {{127,0,0,1}, 3003}}, elli_tcp:peername(Socket)),
	?assertMatch({ok, _Port}, elli_tcp:port(Socket)),
	Req = <<"GET /hello HTTP/1.1\r\nConnection: close\r\n\r\n">>,
    ?assertEqual(ok, elli_tcp:send(Socket, Req)),
    ?assertEqual({ok, <<"HTTP/1.1 200 OK">>}, 
    	elli_tcp:recv(Socket, 15, 10000)),
	ok.

%%
%% Helpers
%% 

start_apps() ->
	application:start(crypto),
    application:start(public_key),
    application:start(ssl),
    inets:start().

%% Start a http server to test the connect function.
setup_elli_http_server() ->
	start_apps(),

    {ok, P} = elli:start_link([
    	{port, 3003}, 
    	{listen_opts, [
    		{reuseaddr, true}
    	]},
    	{callback, elli_example_callback}
    ]),
    unlink(P),
    [P].

%% Start a https server to test the connect function.
setup_elli_https_server() ->
    start_apps(),

    EbinDir = filename:dirname(code:which(?MODULE)),
    CertDir = filename:join([EbinDir, "..", "test"]),
    CertFile = filename:join(CertDir, "server_cert.pem"),
    KeyFile = filename:join(CertDir, "server_key.pem"),
    
    {ok, P} = elli:start_link([
    	{port, {ssl, 3003}},
    	{listen_opts, [
    		{reuseaddr, true},
    		{keyfile, KeyFile},
    		{certfile, CertFile}
    	]}, 
    	{callback, elli_example_callback}
    	
    ]),
    unlink(P),
    [P].

teardown(Pids) ->
    [elli:stop(P) || P <- Pids].

