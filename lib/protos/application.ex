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
    #'ThousandIsland.Logger.attach_logger(:trace)

    children = [
      {Registry, keys: :duplicate, name: Registry.BudgetChat},
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
      {Protos.Database, 9905}
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Protos.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
