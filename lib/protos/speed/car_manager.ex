defmodule Protos.Speed.CarManager do
  use GenServer
  require Logger

  defp via(name) do
    {:via, Registry, {Registry.RoadManagers, name}}
  end

  def day(timestamp), do: floor(timestamp / 86400)

  def speed(mile2, mile1, time2, time1) do
    (mile2 - mile1) / (time2 - time1) * 3600 * 100
  end

  def speeding?(mile2, mile1, time2, time1, limit) do
    speed = (mile2 - mile1) / (time2 - time1) * 3600
    result = speed > limit
    result
  end

  def start_link(name) do
    GenServer.start_link(__MODULE__, [], name: via(name))
  end

  def start_supervised(name) do
    DynamicSupervisor.start_child(DynamicSupervisor.CarSupervisor, {__MODULE__, name})
  end

  def init(_state) do
    issued = ETS.Set.new!()
    Process.send_after(self(), :dispatch_tickets, 500)
    {:ok, %{issued: issued, plates: [], pending: []}}
  end

  def add_plate(plate, details) do
    start_supervised(plate)
    GenServer.cast(via(plate), {:plate, details})
  end

  def get_state(plate) do
    GenServer.call(via(plate), :get)
  end

  def handle_call(:get, _from, state) do
    {:reply, state, state}
  end

  def handle_cast({:plate, details}, state) do
    state = update_in(state[:plates], fn plates -> [details | plates] end)

    tickets =
      state[:plates]
      |> Enum.sort_by(fn details -> details[:timestamp] end)
      |> Enum.chunk_every(2, 1, :discard)
      |> Enum.filter(fn [a, b] ->
        finish = max(a[:mile], b[:mile])
        start = min(a[:mile], b[:mile])
        speeding?(finish, start, b[:timestamp], a[:timestamp], b[:limit])
      end)

    # issue tickets for everything left.
    tickets =
      Enum.map(tickets, fn [a, b] ->
        finish = max(a[:mile], b[:mile])
        start = min(a[:mile], b[:mile])

        %{
          plate: a[:plate],
          road: a[:road],
          mile1: a[:mile],
          timestamp1: a[:timestamp],
          mile2: b[:mile],
          timestamp2: b[:timestamp],
          speed: trunc(speed(finish, start, b[:timestamp], a[:timestamp]))
        }
      end)

    state = update_in(state[:pending], fn pending -> tickets ++ pending end)

    {:noreply, state}
  end

  def dispatch(dispatcher, ticket, state) do
    day1 = ETS.Set.get!(state[:issued], day(ticket[:timestamp1]))
    day2 = ETS.Set.get!(state[:issued], day(ticket[:timestamp2]))

    if day1 == nil and day2 == nil do
      GenServer.cast(dispatcher, {:dispatch_ticket, ticket})
      ETS.Set.put!(state[:issued], {day(ticket[:timestamp1])})
      ETS.Set.put!(state[:issued], {day(ticket[:timestamp2])})
    else
      Logger.warn(
        "Would have re-issued a ticket, But I stopped it as we already issued it"
      )
    end
  end

  def handle_info(:dispatch_tickets, state) do
    Process.send_after(self(), :dispatch_tickets, 500)

    pending_tickets =
      Enum.filter(state[:pending], fn ticket ->
        case Registry.lookup(Registry.SpeedDispatchers, ticket[:road]) do
          [] ->
            true

          dispatchers ->
            {dispatcher, nil} = Enum.random(dispatchers)
            dispatch(dispatcher, ticket, state)
            false
        end
      end)

    {:noreply, Map.put(state, :pending, pending_tickets)}
  end
end
