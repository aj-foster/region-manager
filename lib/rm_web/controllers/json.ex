defmodule RMWeb.JSON do
  def success(data) do
    %{success: true, data: data, errors: nil}
  end

  def error(error) do
    %{success: false, data: nil, errors: [error]}
  end

  def errors(errors) when is_list(errors) do
    %{success: false, data: nil, errors: errors}
  end
end
