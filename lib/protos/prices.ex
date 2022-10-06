defmodule Protos.Prices do
  require Logger
  use ThousandIsland.Handler
  alias ThousandIsland.Socket

  def parse_buffer(_, packets \\ [])

  def parse_buffer(<<packet::binary-size(9), rest::binary>>, packets) do
    parse_buffer(rest, [packet | packets])
  end

  def parse_buffer(buffer, packets) do
    {buffer, packets}
  end

  def decode(<<"I", timestamp::integer-signed-32, price::integer-signed-32>>) do
    {:input, timestamp, price}
  end

  def decode(<<"Q", mintime::integer-signed-32, maxtime::integer-signed-32>>) do
    {:query, mintime, maxtime}
  end

  def process({:input, timestamp, price}, state, _socket) do
    [{timestamp, price} | state]
  end

  def process({:query, mintime, maxtime}, state, socket) do
    query =
      Enum.filter(state, fn {timestamp, _price} ->
        mintime <= timestamp and timestamp <= maxtime
      end)
      |> Enum.map(fn {_timestamp, price} -> price end)

    cond do
      Enum.empty?(query) ->
        Socket.send(socket, <<0::32>>)

      mintime > maxtime ->
        Socket.send(socket, <<0::32>>)

      true ->
        mean = floor(Enum.sum(query) / Enum.count(query))
        Socket.send(socket, <<mean::integer-signed-32>>)
    end

    state
  end

  @impl ThousandIsland.Handler
  def handle_data(data, socket, {buffer, state}) do
    buffer = [buffer | data]

    {buffer, packets} = parse_buffer(IO.iodata_to_binary(buffer))

    instructions = Enum.map(packets, &decode/1)

    {inputs, queries} =
      Enum.split_with(instructions, fn
        {:input, _, _} -> true
        {:query, _, _} -> false
      end)

    state = Enum.reduce(inputs, state, &process(&1, &2, socket))

    Enum.each(queries, fn query ->
      process(query, state, socket)
    end)

    {:continue, {buffer, state}}
  end
end
