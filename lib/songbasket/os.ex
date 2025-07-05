defmodule Songbasket.OS do
  def open_url(url) do
    {cmd, args} =
      case :os.type() do
        {:win32, _} ->
          {"cmd", ["/c", "start", String.replace(url, "&", "^&")]}

        {:unix, :darwin} ->
          {"open", [url]}

        {:unix, _} ->
          if System.find_executable("xdg-open") do
            {"xdg-open", [url]}
          else
            raise "No suitable command found to open URLs"
          end
      end

    System.cmd(cmd, args)
  end
end
