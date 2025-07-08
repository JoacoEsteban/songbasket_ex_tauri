defmodule Songbasket.ExternalResourcesCache do
  require Logger
  @dir :code.priv_dir(:songbasket) |> Path.join("cache/resources")

  File.mkdir_p!(@dir)

  def get(url) do
    id = hash(url)

    case get_cached(id) do
      {:ok, file} ->
        {file, id, path(id)}

      {:error, :enoent} ->
        Logger.info("Fetching external resource: #{url}")

        {:ok, response} =
          Finch.build(:get, url, [], [], [])
          |> Finch.request(Songbasket.Finch)

        %{
          status: 200,
          body: body,
          headers: headers
        } = response

        {_, mime} = List.keyfind(headers, "content-type", 0)

        base64 = Base.encode64(body)
        data_uri = "data:#{mime};base64,#{base64}"

        put_cached(id, data_uri)

        {data_uri, id, path(id)}
    end
  end

  def get(url, :binary) do
    {data_uri, _, _} = get(url)

    {mime, b64} =
      data_uri
      |> String.split(";base64,", parts: 2)
      |> case do
        [<<"data:", mime::binary>>, b64] -> {mime, b64}
      end

    {:ok, binary} = Base.decode64(b64)

    {:ok, {mime, binary}}
  end

  defp get_cached(id) do
    File.read(path(id))
  end

  defp put_cached(id, content) do
    File.write(path(id), content)
  end

  defp path(id) do
    @dir |> Path.join(id)
  end

  defp hash(url) do
    :crypto.hash(:sha256, url) |> Base.encode16()
  end
end
