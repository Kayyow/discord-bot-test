defmodule ElixirLab do
  def start do
    import Supervisor.Spec

    # List comprehension creates a consumer per cpu core
    children = for i <- 1..System.schedulers_online, do: worker(ExampleConsumer, [], id: i)

    Supervisor.start_link(children, strategy: :one_for_one)
  end
end

defmodule ExampleConsumer do  
  use Nostrum.Consumer

  alias Nostrum.Api

  require Logger

  def start_link do
    Consumer.start_link(__MODULE__, strategy: :one_for_one)
  end

  def handle_event({:MESSAGE_CREATE, {msg}, _ws_state}, state) do
    cond do
      String.starts_with? msg.content, "!" ->
        [cmd | args] = msg.content |> String.slice(1..-1) |> String.split
	run_command(cmd, args, msg)
      msg.content == "😦" ->
        Api.create_message(msg.channel_id, "Pleure pas PD !")
      true ->
        :ignore
    end

    {:ok, state}
  end

  # Default event handler, if you don't include this, your consumer WILL crash if
  # you don't have a method definition for each event type.
  def handle_event(_, state) do
    {:ok, state}
  end

  defp run_command("say", args, msg) do
    Api.create_message(msg.channel_id, Enum.join(args))
    Api.delete_message(msg.channel_id, msg)
  end

  defp run_command("d", args, msg) do
    dice_faces = args |> Enum.at(0) |> String.to_integer
    random = Enum.random(1..dice_faces) |> Integer.to_string
    Api.create_message(msg.channel_id, "<@#{msg.author.id}> #{random}")
  end
end
