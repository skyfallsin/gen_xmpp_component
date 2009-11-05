-module(gen_xmpp_component).
-behavior(gen_server).

-include_lib("exmpp/include/exmpp_client.hrl").
-include_lib("exmpp/include/exmpp_xml.hrl").
-include_lib("exmpp/include/exmpp_nss.hrl").

-export([start_link/0, stop/0, start/0]).
-export([init/1, handle_call/3, handle_cast/2, handle_info/2, terminate/2,
         code_change/3, init/0]).

-define(COMPONENT, "notify.localhost").
-define(SECRET, "sekret").
-define(SERVER_HOST, "localhost").
-define(SERVER_PORT, 12001).

-record(state, {session}).

start_link() ->
	gen_server:start_link({local,?MODULE}, ?MODULE, [], []).

start() ->
	gen_server:start({local,?MODULE}, ?MODULE, [], []).

stop() ->
	gen_server:call(?MODULE, stop).

init([]) ->
	exmpp:start(),
	io:format("Started eXMPP~n", []),
	Session = exmpp_component:start_link(),
	exmpp_component:auth(Session, ?COMPONENT, ?SECRET),
	_StreamId = exmpp_component:connect(Session, ?SERVER_HOST, ?SERVER_PORT),
	ok = exmpp_component:handshake(Session),
	{ok, #state{session = Session}}.
init() -> init([]).

handle_call(stop, _From, State) ->
	exmpp_component:stop(State#state.session),
	{stop, normal, ok, State};
handle_call(_Msg, _From, State) ->
	{reply, unexpected, State}.

handle_info(#received_packet{} = Packet, #state{session = S} = State) ->
	spawn_link(fun() -> process_received_packet(S, Packet) end),
	{noreply, State};
handle_info(#received_packet{packet_type=Type, raw_packet=Packet}, State) ->
	error_logger:warning_msg("Unknown packet received(~p): ~p", [Type, Packet]),
	{noreply, State};
handle_info(_Msg, State) ->
	{noreply, State}.

handle_cast(_Msg, State) ->
	{noreply, State}.

terminate(_Reason, _State) ->
	ok.

code_change(_OldVsn, State, _Extra) ->
	{ok, State}.

% -- utility methods --
get_cdata(Packet, Element) -> 
	binary_to_list(exmpp_xml:get_cdata(exmpp_xml:get_element(Packet, Element))).
get_attr(Elem, Attr) ->
	case exmpp_xml:get_attribute_as_list(Elem, Attr, 0) of
		0 -> erlang:raise();
		Result -> Result
	end.

% -----------
process_received_packet(_Session, Packet) ->
	io:format("Unknown packet: ~p~n", [Packet]).
