defmodule Songbasket.Auth do
  alias Songbasket.{Api, OS, MemoryStore}
  @token_name :songbasket_one_time_token
  @secret_name :songbasket_one_time_secret

  def start_login_flow do
    {:ok, %{token: token, secret: secret}, _response} = Api.request_auth()

    MemoryStore.put(@token_name, token)
    MemoryStore.put(@secret_name, secret)

    url =
      Api.login_url()
      |> Map.put(:query, %{@token_name => token} |> URI.encode_query())
      |> URI.to_string()

    OS.open_url(url)
  end

  def retrieve_token do
    {:ok, secret} =
      MemoryStore.get(@secret_name)

    {:ok, token} =
      MemoryStore.get(@token_name)

    {:ok, response, _} =
      Api.retrieve_token(headers: auth_headers(token, secret))

    {:ok, response}
  end

  defp auth_headers(token, secret) do
    [{@secret_name, secret}, {@token_name, token}]
    |> Enum.map(fn {key, val} -> {Atom.to_string(key), val} end)
  end
end
