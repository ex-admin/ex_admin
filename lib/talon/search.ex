defmodule Talon.Search do
  @moduledoc """
  Handle default search capabilities for an ecto schema.
  """
  require Ecto.Query
  import Ecto.Query

  @doc """
  Default freetext search handler
  """
  @spec search(Module.t, Module.t, String.t) :: Ecto.Query.t
  def search(_, schema, nil), do: where(schema, true)
  def search(talon_resource, schema, search_terms) do
    cond do
      function_exported?(talon_resource, :search_fields, 0) ->
        {:cont, apply(talon_resource, :search_fields, [])}
      function_exported?(talon_resource, :search_query, 1) ->
        {:halt, apply(talon_resource, :search_query, [search_terms])}
      true ->
        # TODO: this will not work if no string type is found
        {:cont, find_string_fields(talon_resource, schema)}
    end
    |> build_query(schema, search_terms)
  end

  defp find_string_fields(talon_resource, schema) do
    string_fields =
      :types
      |> schema.__schema__
      |> Enum.reduce([], fn
        {field, :string}, acc -> [field | acc]
        _, acc -> acc
      end)

    talon_resource.display_schema_columns(:index)
    |> Enum.filter(& &1 in string_fields)
  end

  @spec build_query(tuple, Struct.t | Module.t, String.t) :: Ecto.Query.t
  def build_query({:halt, query}, _, _), do: query
  def build_query({:cont, fields}, schema, search_terms) do
    dynamic =
      fields
      |> field_types(schema)
      |> query_builder(false, search_terms)

    from schema, where: ^dynamic
  end

  defp field_types(atom, schema) when is_atom(atom) do
    [{atom, schema.__schema__(:type, atom)}]
  end
  defp field_types(list, schema) when is_list(list) do
    Enum.map(list, & {&1, schema.__schema__(:type, &1)})
  end

  defp query_builder([], dynamic, _search_terms), do: dynamic
  defp query_builder([{field, type} | tail], dynamic, search_terms) do
    query_builder(tail, build_query_type(type, field, dynamic, search_terms), search_terms)
  end

  defp build_query_type(:string, field, dynamic, search_terms) do
    match = "%" <> String.downcase(search_terms) <> "%"
    dynamic([q], like(fragment("LOWER(?)", field(q, ^field)), ^match) or ^dynamic)
  end
  defp build_query_type(_type, field, dynamic, search_terms) do
    dynamic([q], field(q, ^field) == ^search_terms or ^dynamic)
  end
end
