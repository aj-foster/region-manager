defmodule RMWeb.JSON do
  @typedoc "Generic API response"
  @type response :: response(boolean, term, [term] | nil)
  @typedoc "Generic API response"
  @type response(success?, data, errors) :: %{success: success?, data: data, errors: errors}

  @typedoc "Successful API response"
  @type success :: success(term)
  @typedoc "Successful API response"
  @type success(data) :: response(true, data, nil)

  @typedoc "Unsuccessful API response"
  @type error :: error([term])
  @typedoc "Unsuccessful API response"
  @type error(errors) :: response(false, nil, errors)

  @spec success(data) :: success(data) when data: term
  def success(data) do
    %{success: true, data: data, errors: nil}
  end

  @spec error(error) :: error([error]) when error: term
  def error(error) do
    %{success: false, data: nil, errors: [error]}
  end

  @spec errors(errors) :: error(errors) when errors: term
  def errors(errors) when is_list(errors) do
    %{success: false, data: nil, errors: errors}
  end
end
