defmodule Protohack.Mitm do
  @moduledoc """
  Solution for Mob in the Middle
  """
  use GenServer

  require Logger

  @upstream_server ~c"chat.protohackers.com"
  @upstream_port 16_963
  @tony_boguscoin_addr "7YWHMfk9JZe0LM0g1ZauHuiSxhI"

  @opts [
    :binary,
    active: false,
    reuseaddr: true,
    packet: :line
  ]

  def start_link(port: port) do
    GenServer.start_link(__MODULE__, port, name: __MODULE__)
  end

  @impl GenServer
  def init(port) do
    case :gen_tcp.listen(port, @opts) do
      {:ok, listen_socket} ->
        Logger.info("Accepting connections for Mob in the Middle on port #{port}")

        Task.start_link(fn ->
          loop_acceptor(listen_socket)
        end)

        state = %{users: %{}}
        {:ok, state}

      {:error, reason} ->
        {:stop, reason}
    end
  end

  defp loop_acceptor(ls_socket) do
    case :gen_tcp.accept(ls_socket) do
      {:ok, client} ->
        {:ok, upstream_socket} = :gen_tcp.connect(@upstream_server, @upstream_port, @opts)

        Task.start_link(fn ->
          handle_client(client, upstream_socket)
        end)

        loop_acceptor(ls_socket)

      {:error, reason} ->
        Logger.debug("Accept failed #{inspect(reason)}")
        :ok
    end
  end

  defp handle_client(client, upstream_socket) do
    Task.Supervisor.start_child(Protohack.BudgetChat.Supervisor, fn ->
      Task.start(fn -> pass_through(client, upstream_socket) end)
      pass_through(upstream_socket, client)
    end)
  end

  defp pass_through(receiver, sender) do
    case :gen_tcp.recv(sender, 0) do
      {:ok, data} ->
        attacked_data = inject_boguscoin_addr(data)
        :gen_tcp.send(receiver, attacked_data)
        pass_through(receiver, sender)

      {:error, :closed} ->
        :gen_tcp.close(receiver)
    end
  end

  defp inject_boguscoin_addr(str) do
    bogus_regex = ~r/(?<=^| )7[a-zA-Z0-9]{25,34}(?=$| )/

    Regex.replace(bogus_regex, str, @tony_boguscoin_addr)
  end
end
