defmodule RMWeb.Email do
  use RMWeb, :html

  embed_templates "email/*.html", suffix: "_html"
  embed_templates "email/*.text", suffix: "_text"
end
