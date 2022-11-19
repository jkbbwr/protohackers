defmodule Protos.Speed do
  use ThousandIsland.Handler
  alias ThousandIsland.Socket
  require Logger

  @error 0x10
  @plate_packet 0x20
  @ticket 0x21
  @want_heartbeat 0x40
  @i_am_camera 0x80
  @i_am_dispatcher 0x81

  def packet(
        <<@plate_packet, data_size::8, plate::binary-size(data_size),
          timestamp::integer-unsigned-32, rest::binary>>
      ) do
    {{:plate, plate, timestamp}, rest}
  end

  def packet(<<@plate_packet, rest::binary>>), do: {:incomplete, <<@plate_packet, rest::binary>>}

  def packet(<<@want_heartbeat, interval::integer-unsigned-32, rest::binary>>) do
    {{:heartbeat, interval}, rest}
  end

  def packet(<<@want_heartbeat, rest::binary>>),
    do: {:incomplete, <<@want_heartbeat, rest::binary>>}

  def packet(
        <<@i_am_camera, road::integer-unsigned-16, mile::integer-unsigned-16,
          limit::integer-unsigned-16, rest::binary>>
      ) do
    {{:camera, road, mile, limit}, rest}
  end

  def packet(<<@i_am_camera, rest::binary>>), do: {:incomplete, <<@i_am_camera, rest::binary>>}

  def packet(
        <<@i_am_dispatcher, numroads::8, roads::size(numroads)-unit(16)-binary, rest::binary>>
      ) do
    {{:dispatcher, for(<<x::16 <- roads>>, do: x)}, rest}
  end

  def packet(<<@i_am_dispatcher, rest::binary>>),
    do: {:incomplete, <<@i_am_dispatcher, rest::binary>>}

  def packet(<<>>), do: {:incomplete, <<>>}

  def packet(rest), do: {:invalid, rest}

  def heartbeat(), do: <<0x41>>

  def ticket(plate, road, mile1, timestamp1, mile2, timestamp2, speed) do
    <<
      @ticket,
      String.length(plate)::8,
      plate::binary,
      road::integer-unsigned-16,
      mile1::integer-unsigned-16,
      timestamp1::integer-unsigned-32,
      mile2::integer-unsigned-16,
      timestamp2::integer-unsigned-32,
      speed::integer-unsigned-16
    >>
  end

  def error(message), do: <<@error, String.length(message)::8, message::binary>>

  def handle_packet({:heartbeat, 0}, state, _socket), do: state

  def handle_packet({:heartbeat, interval}, state, _socket) do
    ms = interval * 100
    Process.send_after(self(), {:heartbeat, ms}, ms)
    state
  end

  def handle_packet({:plate, plate, timestamp}, state, _socket) when state.mode == :camera do
    road = state.metadata[:road]
    limit = state.metadata[:limit]
    mile = state.metadata[:mile]

    record = %{
      road: road,
      mile: mile,
      plate: plate,
      timestamp: timestamp,
      limit: limit
    }

    Protos.Speed.CarManager.add_plate(plate, record)

    state
  end

  def handle_packet({:plate, _, _}, state, socket) do
    Socket.send(socket, error("You sent a plate but you are not a camera."))
    Socket.close(socket)
    state
  end

  def handle_packet({:camera, road, mile, limit}, state, _socket) when state.mode == :unknown do
    Logger.info("I am a camera on road: #{road}, mile: #{mile} and the limit is #{limit}")
    %{state | mode: :camera, metadata: [road: road, mile: mile, limit: limit]}
  end

  def handle_packet({:camera, _road, _mile, _limit}, state, socket) do
    Logger.warn("A device just tried to change state from #{state.mode} to :camera")
    Socket.send(socket, error("You cannot become a camera."))
    Socket.close(socket)
    state
  end

  def handle_packet({:dispatcher, roads}, state, _socket) when state.mode == :unknown do
    Logger.info("I am a dispatcher. I handle: #{inspect(roads)}")
    Enum.each(roads, fn road -> Registry.register(Registry.SpeedDispatchers, road, nil) end)
    %{state | mode: :dispatcher, metadata: [roads: roads]}
  end

  def handle_packet({:dispatcher, _roads}, state, socket) do
    Logger.warn("A device just tried to change state from #{state.mode} to :dispatcher")
    Socket.send(socket, error("You cannot become a dispatcher."))
    Socket.close(socket)
    state
  end

  def parse_packets(buffer, packets \\ [])

  def parse_packets(buffer, packets) do
    case packet(buffer) do
      {:incomplete, rest} ->
        {rest, packets}

      {:invalid, _rest} ->
        Logger.error("invalid packet???\n#{inspect(buffer)}\n#{inspect(packets)}")
        raise "invalid packet"

      {packet, rest} ->
        parse_packets(rest, [packet | packets])
    end
  end

  @impl ThousandIsland.Handler
  def handle_data(data, socket, state) do
    try do
      {buffer, packets} = parse_packets(state[:buffer] <> data)
      state = Map.put(state, :buffer, buffer)

      state =
        Enum.reduce(packets, state, fn packet, state ->
          handle_packet(packet, state, socket)
        end)

      {:continue, state}
    rescue
      RuntimeError ->
        Socket.send(socket, error("You sent me junk"))
        {:close, state}
    end
  end

  def handle_cast({:dispatch_ticket, ticket}, {conn, _state} = state) do
    Socket.send(
      conn,
      ticket(
        ticket[:plate],
        ticket[:road],
        ticket[:mile1],
        ticket[:timestamp1],
        ticket[:mile2],
        ticket[:timestamp2],
        ticket[:speed]
      )
    )

    {:noreply, state}
  end

  def handle_info({:heartbeat, ms}, {conn, _state} = state) do
    Socket.send(conn, heartbeat())
    Process.send_after(self(), {:heartbeat, ms}, ms)
    {:noreply, state}
  end
end
