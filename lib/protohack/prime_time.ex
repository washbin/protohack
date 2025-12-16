defmodule Protohack.PrimeTime do
  @moduledoc """
  Solution to PrimeTime
  """
  use GenServer

  require Logger

  @opts [
    :binary,
    active: false,
    packet: :line,
    reuseaddr: true
  ]

  def start_link(port: port) do
    GenServer.start_link(__MODULE__, port)
  end

  @impl GenServer
  def init(port) do
    case :gen_tcp.listen(port, @opts) do
      {:ok, listen_socket} ->
        Logger.info("Accepting connections for prime time on port #{port}")
        Task.start_link(fn -> loop_acceptor(listen_socket) end)
        state = %{listen_socket: listen_socket}
        {:ok, state}

      {:error, reason} ->
        {:stop, reason}
    end
  end

  defp loop_acceptor(ls_socket) do
    case :gen_tcp.accept(ls_socket) do
      {:ok, client} ->
        Task.start(fn -> serve(client) end)
        loop_acceptor(ls_socket)

      {:error, _reason} ->
        # Logger.error("Accept failed #{inspect(reason)}")
        :ok
    end
  end

  defp serve(socket) do
    with {:ok, data} <- read_line(socket),
         {:ok, json} <- JSON.decode(data),
         {:ok, resp} <- craft_resp(json) do
      encoded = JSON.encode!(resp)
      :gen_tcp.send(socket, encoded <> "\n")
      serve(socket)
    else
      {:error, :closed} ->
        :ok

      {:error, _reason} ->
        # Logger.error("Failed with clause due to #{inspect(reason)}")
        :gen_tcp.send(socket, "malformed\n")
        :gen_tcp.close(socket)
        exit(:shutdown)
    end
  end

  defp craft_resp(%{"method" => "isPrime", "number" => num}) when is_number(num),
    do: {:ok, %{"method" => "isPrime", "prime" => prime?(num)}}

  defp craft_resp(_malformed), do: {:error, :malformed_input}

  defp read_line(socket) do
    msg = :gen_tcp.recv(socket, 0)
    msg
  end

  defp prime?(n) when is_float(n), do: false
  defp prime?(n) when n <= 1, do: false
  defp prime?(n) when n in [2, 3], do: true

  defp prime?(n) do
    sqrt = trunc(:math.sqrt(n))

    not Enum.any?(2..sqrt, &(rem(n, &1) == 0))
  end
end
