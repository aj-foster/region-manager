defmodule Console do
  if Mix.env() == :dev do
    def reload do
      Phoenix.CodeReloader.reload(RMWeb.Endpoint)
    end

    def fl do
      RM.Repo.get_by(RM.FIRST.Region, code: "USFL")
    end
  end
end

import Console
