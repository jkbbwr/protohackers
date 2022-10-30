defmodule Protos.Mob do
  use ThousandIsland.Handler
  alias ThousandIsland.Socket
  require Logger

  @tony_address "7YWHMfk9JZe0LM0g1ZauHuiSxhI"
  @address_regex ~r/(?<=^| )(7[[:alnum:]]{25,35})(?=$| )/m

  @impl ThousandIsland.Handler
  def handle_connection(downstream, _state) do
    {:ok, pid} = Task.start_link(__MODULE__, :upstream_init, [downstream])
    {:continue, %{upstream: pid}}
  end

  def upstream_init(downstream) do
    {:ok, upstream} =
      :gen_tcp.connect('chat.protohackers.com', 16963, active: true, packet: :line, buffer: 32000)

    :gen_tcp.controlling_process(upstream, self())

    upstream_loop(upstream, downstream)
  end

  def upstream_loop(upstream, downstream) do
    receive do
      {:tcp, _, data} ->
        Socket.send(downstream, hack_message(data))
        upstream_loop(upstream, downstream)

      {:tcp_closed, _} ->
        Socket.close(downstream)

      {:tcp_error, _} ->
        Socket.close(downstream)

      {:send, data} ->
        :gen_tcp.send(upstream, hack_message(data))
        upstream_loop(upstream, downstream)
    end
  end

  def hack_message(message) do
    Logger.info(message)
    Regex.replace(@address_regex, to_string(message), @tony_address)
  end

  @impl ThousandIsland.Handler
  def handle_data(data, _socket, state) do
    send(state.upstream, {:send, data})
    {:continue, state}
  end
end
