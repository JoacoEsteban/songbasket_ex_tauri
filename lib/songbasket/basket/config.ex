defmodule Songbasket.Basket.Config do
  import Songbasket.Basket
  alias Songbasket.{Basket}
  alias Songbasket.Basket.{User}
  use Ecto.Schema
  import Ecto.Changeset

  schema "config" do
    field :token, :string
    belongs_to :user, User, type: :string
  end

  def changeset(attrs) do
    %__MODULE__{}
    |> cast(attrs, [:token, :user_id])
    |> validate_required([:token, :user_id])
    |> put_change(:id, 0)
  end

  def get do
    Basket.one!(__MODULE__)
  end

  def get_token do
    get().token
  end
end
