defmodule Protos.Prime do
  require Logger
  use ThousandIsland.Handler
  alias ThousandIsland.Socket

  def handle(%{"method" => "isPrime", "number" => number}, socket)
      when is_integer(number) do
    %{"method" => "isPrime", "prime" => Prime.test(number)}
    |> Jason.encode!()
    |> then(fn response -> Socket.send(socket, [response, "\n"]) end)
  end

  def handle(%{"method" => "isPrime", "number" => number}, socket)
      when is_float(number) do
    %{"method" => "isPrime", "prime" => false}
    |> Jason.encode!()
    |> then(fn response -> Socket.send(socket, [response, "\n"]) end)
  end

  def handle(_, socket) do
    %{}
    |> Jason.encode!()
    |> then(fn response -> Socket.send(socket, [response, "\n"]) end)

    Socket.close(socket)
  end

  @impl ThousandIsland.Handler
  def handle_data(data, socket, state) do
    case Jason.decode(data) do
      {:ok, payload} ->
        handle(payload, socket)
        {:continue, state}

      {:error, _error} ->
        Socket.send(socket, [Jason.encode!(%{error: "Failed to decode json"}), "\n"])
        {:close, state}
    end
  end
end
