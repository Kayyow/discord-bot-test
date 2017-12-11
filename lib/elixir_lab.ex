defmodule ElixirLab do
  def main(args \\ []) do
    start()
  end

  def start do
    import Supervisor.Spec

    # List comprehension creates a consumer per cpu core
    children = for i <- 1..System.schedulers_online, do: worker(ElixirLabConsumer, [], id: i)

    Supervisor.start_link(children, strategy: :one_for_one)
  end
end

defmodule ElixirLabConsumer do  
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

  def crawl_nfl_stream(keyword) do
    url = "https://www.reddit.com/r/nflstreams/"
    {:ok, opts} = Crawler.crawl(url, max_depths: 1)
    :timer.sleep(1000)
    page = Crawler.Store.find(url)
    links = Floki.find(page.body, "a.title")
    links_attributes = Enum.map(links, fn({"a", attributes, _}) -> attributes end)
    clean_attributes = Enum.map(links_attributes, fn(x) -> List.keytake(x, "href", 0) end)
    href_list = Enum.map(clean_attributes, fn({{"href", a}, _}) -> a end)
    link = "https://www.reddit.com" <> (Enum.filter(href_list, fn(x) -> Regex.match?(~r/#{keyword}/, x) end) |> List.first)
    {:ok, opts} = Crawler.crawl(link, max_depths: 1)
    :timer.sleep(1000)
    page2 = Crawler.Store.find(link)
    links2 = Floki.find(page2.body, ".nestedlisting .thing:first-of-type table tbody tr:first-of-type td:nth-of-type(2) a")
    {"a", href, _} = List.first links2
    {"href", stream_url} = List.first href
    IO.puts stream_url
    # stream_url
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

  defp run_command("nfl", args, msg) do
    Api.create_message(msg.channel_id, crawl_nfl_stream(args))
  end
end
