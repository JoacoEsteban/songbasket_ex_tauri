# defmodule SongbasketPhoenix.EncryptedField do
#   use Ecto.Type
#   alias SongbasketPhoenix.Crypto

#   def type, do: :binary

#   def cast(value) when is_binary(value), do: {:ok, value}
#   def cast(_), do: :error

#   def dump(plaintext) do
#     {:ok, Crypto.encrypt(plaintext)}
#   end

#   def load(ciphertext) do
#     {:ok, Crypto.decrypt(ciphertext)}
#   end
# end
