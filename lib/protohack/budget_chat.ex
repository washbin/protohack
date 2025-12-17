defmodule Protohack.BudgetChat do
  @moduledoc """
  Solution for challenge 3, Budget Chat
  """
  use GenServer

  require Logger

  @opts [
    :binary,
    active: false,
    reuseaddr: true,
    packet: :line
  ]

  def start_link(port: port) do
    GenServer.start_link(__MODULE__, port, name: __MODULE__)
  end

  def join(name, pid), do: GenServer.call(__MODULE__, {:join, name, pid})
  def leave(name), do: GenServer.cast(__MODULE__, {:leave, name})
  def broadcast(from, msg), do: GenServer.cast(__MODULE__, {:broadcast, from, msg})
  def check(name), do: GenServer.call(__MODULE__, {:check, name})

  @impl GenServer
  def init(port) do
    case :gen_tcp.listen(port, @opts) do
      {:ok, listen_socket} ->
        Logger.info("Accepting connections for budget chat on port #{port}")
        Task.start_link(fn -> loop_acceptor(listen_socket) end)
        state = %{users: %{}}
        {:ok, state}

      {:error, reason} ->
        {:stop, reason}
    end
  end

  @impl GenServer
  def handle_call({:join, name, pid}, _from, state) do
    Process.monitor(pid)

    Enum.each(state.users, fn {_n, id} ->
      send(id, {:system, "* #{name} has entered the room"})
    end)

    existing = Map.keys(state.users)
    new_all_users = Map.put(state.users, name, pid)

    {:reply, {:ok, existing}, %{state | users: new_all_users}}
  end

  @impl GenServer
  def handle_call({:check, input_name}, _from, state) do
    name = String.trim(input_name)
    duplicate_name? = Enum.any?(state.users, fn {n, _} -> n == name end)

    valid_name? =
      String.match?(name, ~r/[a-zA-Z]/) and
        String.match?(name, ~r/^[a-zA-Z0-9]{3,20}$/)

    case {duplicate_name?, valid_name?} do
      {false, true} ->
        {:reply, {:ok, name}, state}

      {true, _} ->
        {:reply, {:error, :duplicate_name}, state}

      {_, false} ->
        {:reply, {:error, :illegal_name}, state}
    end
  end

  @impl GenServer
  def handle_cast({:leave, name}, state) do
    {pid, new_all_users} = Map.pop(state.users, name)

    if pid do
      Enum.each(new_all_users, fn {_n, id} ->
        send(id, {:system, "* #{name} has left the room"})
      end)
    end

    {:noreply, %{state | users: new_all_users}}
  end

  @impl GenServer
  def handle_cast({:broadcast, from, msg}, state) do
    Enum.each(state.users, fn {name, pid} ->
      if name != from do
        send(pid, {:chat, "[#{from}] #{msg}"})
      end
    end)

    {:noreply, state}
  end

  @impl GenServer
  def handle_info({:DOWN, _, :process, pid, _}, state) do
    case Enum.find(state.users, fn {_n, p} -> p == pid end) do
      {name, _} ->
        leave(name)

      nil ->
        {:noreply, state}
    end
  end

  defp loop_acceptor(ls_socket) do
    case :gen_tcp.accept(ls_socket) do
      {:ok, client} ->
        handle_client(client)
        loop_acceptor(ls_socket)

      {:error, reason} ->
        Logger.debug("Accept failed #{inspect(reason)}")
        :ok
    end
  end

  defp handle_client(client) do
    Task.Supervisor.start_child(Protohack.BudgetChat.Supervisor, fn ->
      :gen_tcp.send(client, "Howdy user, who may you be ?\n")

      with {:ok, msg} <- :gen_tcp.recv(client, 0),
           {:ok, name} <- check(msg),
           {:ok, existing_users} <- join(name, self()) do
        :gen_tcp.send(client, "* Users in room: #{Enum.join(existing_users, ",")}\n")

        # another process to handle tcp messages
        Task.start_link(fn -> tcp_serve(client, name) end)
        # loop to handle local process mailbox
        local_serve(client, name)
      else
        {:error, :duplicate_name} ->
          :gen_tcp.send(client, "Sorry human, name is already taken!\n")
          :gen_tcp.close(client)

        {:error, :illegal_name} ->
          :gen_tcp.send(client, "Sorry human, name is illegal.\n")
          :gen_tcp.close(client)

        {:error, _reason} ->
          :gen_tcp.send(client, "Sorry human, you messed up the beautiful thing between us\n")
          :gen_tcp.close(client)
      end
    end)
  end

  defp local_serve(socket, name) do
    receive do
      {:chat, msg} ->
        :gen_tcp.send(socket, msg <> "\n")
        local_serve(socket, name)

      {:system, msg} ->
        :gen_tcp.send(socket, msg <> "\n")
        local_serve(socket, name)
    end
  end

  defp tcp_serve(socket, name) do
    case :gen_tcp.recv(socket, 0) do
      {:ok, msg} ->
        broadcast(name, String.trim(msg))
        tcp_serve(socket, name)

      {:error, _} ->
        leave(name)
        :gen_tcp.close(socket)
    end
  end
end
