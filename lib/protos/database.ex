defmodule Protos.Database do
  use GenServer
  require Logger

  def start_link(port) do
    GenServer.start_link(__MODULE__, port)
  end

  def init(port) do
    {:ok, socket} = :gen_udp.open(port, [:binary, active: true])
    {:ok, %{}}
  end

  def handle_info({:udp, socket, address, port, "version"}, state) do
    :gen_udp.send(socket, address, port, "version=Ken's Key-Value Store 1.0")
    {:noreply, state}
  end

  def handle_info({:udp, socket, address, port, data}, state) do
    if String.contains?(data, "=") do
      [key, value] = String.split(data, "=", parts: 2)
      {:noreply, Map.put(state, key, value)}
    else
      value = Map.get(state, data, "")
      :gen_udp.send(socket, address, port, [data, "=", value])
      {:noreply, state}
    end
  end
end
