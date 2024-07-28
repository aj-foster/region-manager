defmodule RM.Assertions do
  @moduledoc """
  Helpers for easy-to-read tests.

  This module makes heavy use of macros to preserve nice error messages.
  """

  @doc """
  Assert two values are equal.

  ## Example

      my_function()
      |> assert_equal(2)

  """
  defmacro assert_equal(left, right) do
    quote do
      left = unquote(left)
      assert left == unquote(right)
      left
    end
  end

  @doc """
  Assert the first argument matches the given pattern.

  ## Example

      my_function()
      |> assert_match(%{"key" => _})

  """
  defmacro assert_match(left, right) do
    quote do
      left = unquote(left)
      assert unquote(right) = left
      left
    end
  end

  @doc """
  Assert the given pattern matches at least one item in the enumerable

  ## Example

      my_function()
      |> assert_match_in(%{"key" => _})

  """
  defmacro assert_match_in(left, right) do
    quote do
      left = unquote(left)
      assert Enum.any?(left, &match?(unquote(right), &1))
      left
    end
  end

  @doc """
  Assert a timestamp is recent. Defaults to a 10 second threshold.

  ## Example

    value.last_accessed_at
    |> assert_recent()

  """
  defmacro assert_recent(value, threshold \\ 10) do
    quote do
      assert DateTime.diff(DateTime.utc_now(), unquote(value), :second) <= unquote(threshold)
    end
  end

  @doc """
  Assert two lists are equivalent (in any order).

  This macro uses MapSet to compare two enumerable values in an order-unspecific way. This is not
  suitable for lists that may have duplicate elements.

  ## Example

      my_function()
      |> assert_set_equal([2, 1])

  """
  defmacro assert_set_equal(left, right) do
    quote do
      assert MapSet.new(unquote(left)) == MapSet.new(unquote(right))
    end
  end

  @doc """
  Assert two lists match (in any order).

  Taken from https://elixirforum.com/t/assert-a-list-of-patterns-ignoring-order/46068/8.

  ## Example

      my_function()
      |> assert_set_match([2, 1])

  """
  defmacro assert_set_match(expression, patterns) when is_list(patterns) do
    clauses =
      patterns
      |> Enum.with_index()
      |> Enum.flat_map(fn {pattern, index} ->
        quote generated: true do
          unquote(pattern) -> unquote(index)
        end
      end)
      |> Kernel.++(quote(generated: true, do: (_ -> :not_found)))

    code = Macro.escape({:assert_set_match, [], [expression, patterns]}, prune_metadata: true)
    pins = collect_pins_from_pattern(patterns, Macro.Env.vars(__CALLER__))

    quote generated: true do
      expression = unquote(expression)
      patterns = unquote(Macro.escape(patterns))
      fun = fn x -> case x, do: unquote(clauses) end
      pins = unquote(pins)

      result =
        Enum.reduce(expression, %{}, fn item, acc ->
          case fun.(item) do
            :not_found ->
              raise ExUnit.AssertionError,
                expr: unquote(code),
                left: item,
                message: "Item does not match any pattern\n" <> ExUnit.Assertions.__pins__(pins)

            index when is_map_key(acc, index) ->
              raise ExUnit.AssertionError,
                expr: unquote(code),
                left: [item, acc[index]],
                message: "Multiple items match pattern\n" <> ExUnit.Assertions.__pins__(pins)

            index when is_integer(index) ->
              Map.put(acc, index, item)
          end
        end)

      if map_size(result) == length(patterns) do
        :ok
      else
        raise ExUnit.AssertionError,
          expr: unquote(code),
          left: expression,
          message: "Expected set to have #{length(patterns)} entries, got: #{map_size(result)}\n"
      end
    end
  end

  defp collect_pins_from_pattern(expr, vars) do
    {_, pins} =
      Macro.prewalk(expr, %{}, fn
        {:quote, _, [_]}, acc ->
          {:ok, acc}

        {:quote, _, [_, _]}, acc ->
          {:ok, acc}

        {:^, _, [var]}, acc ->
          identifier = var_context(var)

          if identifier in vars do
            {:ok, Map.put(acc, var_context(var), var)}
          else
            {:ok, acc}
          end

        form, acc ->
          {form, acc}
      end)

    Enum.to_list(pins)
  end

  defp var_context({name, meta, context}) do
    {name, meta[:counter] || context}
  end
end
