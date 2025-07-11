defmodule Songbasket.Flow.Config do
  @derive {Jason.Encoder,
           only: [
             :selected_basket
           ]}
  use Ecto.Schema
  import Ecto.Changeset
  import Ecto.Query

  alias Songbasket.Flow.BasketRecord
  alias Songbasket.Flow.Config

  schema "config" do
    belongs_to :selected_basket, BasketRecord
  end

  def changeset(config, attrs) do
    config
    |> cast(attrs, [:selected_basket_id])
  end
end
