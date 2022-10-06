defmodule Protos.Chat do
  use ThousandIsland.Handler
  alias ThousandIsland.Socket

  @impl ThousandIsland.Handler
  def handle_connection(socket, _state) do
    Socket.send(socket, "Welcome to budgetchat! What shall I call you?\n")
    {:continue, %{joined: false}}
  end

  def handle_cast({:join, username}, {socket, %{joined: true} = state}) do
    Socket.send(socket, "* #{username} has entered the room\n")
    {:noreply, {socket, state}}
  end

  def handle_cast({:broadcast, name, message}, {socket, %{joined: true} = state}) do
    Socket.send(socket, "[#{name}] #{message}\n")
    {:noreply, {socket, state}}
  end

  def handle_cast({:leave, username}, {socket, %{joined: true} = state}) do
    Socket.send(socket, "* #{username} has left the room\n")
    {:noreply, {socket, state}}
  end

  def handle_cast(_, {socket, state}) do
    {:noreply, {socket, state}}
  end

  def user_list() do
    Registry.lookup(Registry.BudgetChat, "main")
    |> Enum.map(fn {_, name} -> name end)
  end

  def join(name) do
    Registry.register(Registry.BudgetChat, "main", name)

    Registry.dispatch(Registry.BudgetChat, "main", fn entries ->
      for {pid, peer} <- entries, peer != name, do: GenServer.cast(pid, {:join, name})
    end)
  end

  def leave(name) do
    Registry.dispatch(Registry.BudgetChat, "main", fn entries ->
      for {pid, peer} <- entries, peer != name, do: GenServer.cast(pid, {:leave, name})
    end)
  end

  def broadcast(name, message) do
    Registry.dispatch(Registry.BudgetChat, "main", fn entries ->
      for {pid, peer} <- entries,
          peer != name,
          do: GenServer.cast(pid, {:broadcast, name, message})
    end)
  end

  @impl ThousandIsland.Handler
  def handle_data(data, socket, %{joined: false} = state) do
    name = String.trim(data)

    if Regex.match?(~r/^[a-zA-Z0-9]+$/, name) do
      users = user_list() |> Enum.join(", ")
      join(name)
      Socket.send(socket, "* The room contains: #{users}\n")
      {:continue, %{joined: true, name: name}}
    else
      Socket.send(socket, "Invalid username.\n")
      {:close, state}
    end
  end

  @impl ThousandIsland.Handler
  def handle_data(data, _socket, state) do
    broadcast(state.name, String.trim(data))
    {:continue, state}
  end

  @impl ThousandIsland.Handler
  def handle_close(_socket, %{joined: false}) do
    :ok
  end

  def handle_close(_socket, state) do
    leave(state.name)
    :ok
  end
end
