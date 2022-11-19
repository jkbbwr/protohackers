defmodule Protos.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  def child_spec(id, spec) do
    Supervisor.child_spec(spec, id: id)
  end

  @impl true
  def start(_type, _args) do
    ThousandIsland.Logger.attach_logger(:info)

    roads = ETS.Bag.new!(name: :speed_roads, protection: :public)
    tickets = ETS.Bag.new!(name: :speed_tickets, protection: :public)

    children = [
      {Registry, keys: :duplicate, name: Registry.BudgetChat},
      {Registry, keys: :duplicate, name: Registry.SpeedDispatchers},
      {Registry, keys: :unique, name: Registry.RoadManagers},
      {DynamicSupervisor, strategy: :one_for_one, name: DynamicSupervisor.CarSupervisor},
      child_spec(:smoke, {ThousandIsland, port: 9901, handler_module: Protos.Smoke}),
      child_spec(
        :prime,
        {ThousandIsland,
         port: 9902,
         handler_module: Protos.Prime,
         transport_options: [packet: :line, buffer: 32000]}
      ),
      child_spec(
        :prices,
        {ThousandIsland, port: 9903, handler_module: Protos.Prices, handler_options: {"", []}}
      ),
      child_spec(
        :chat,
        {ThousandIsland,
         port: 9904,
         handler_module: Protos.Chat,
         handler_options: %{},
         transport_options: [packet: :line, buffer: 32000]}
      ),
      {Protos.Database, 9905},
      child_spec(
        :mob,
        {ThousandIsland,
         port: 9906, handler_module: Protos.Mob, transport_options: [packet: :line, buffer: 32000]}
      ),
      child_spec(
        :speed,
        {ThousandIsland,
         port: 9907,
         handler_module: Protos.Speed,
         handler_options: %{buffer: <<>>, mode: :unknown, metadata: :unknown, roads: roads, tickets: tickets}}
      )
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Protos.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
