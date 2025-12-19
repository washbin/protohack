defmodule Protohack.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      {Protohack.SmokeTest, port: 8989},
      {Protohack.PrimeTime, port: 8990},
      {Protohack.BFormat, port: 8991},
      # Task supervisor for the budget chat
      {Task.Supervisor, name: Protohack.BudgetChat.Supervisor},
      {Protohack.BudgetChat, port: 8992},
      {Protohack.UnusualDatabase, port: 8993},
      {Protohack.Mitm, port: 8994}
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Protohack.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
