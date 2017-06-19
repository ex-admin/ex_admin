defmodule Talon.Concern do
  @moduledoc """


  First, some termonolgy:

  * schema - The name of a give schema. .i.e. TestTalon.Simple
  * talon_resource - the talon module for a given schema. .i.e. TestTalon.Talon.Simple

  ## resource_map

      iex> TestTalon.Talon.resource_map()["simples"]
      TestTalon.Talon.Simple

      iex> TestTalon.Talon.resources() |> Enum.any?(& &1 == TestTalon.Talon.Simple)
      true

      iex> TestTalon.Talon.resource_names()|> Enum.any?(& &1 == "simples")
      true

      iex> TestTalon.Talon.schema("simples")
      TestTalon.Simple

      iex> TestTalon.Talon.schema_names() |> Enum.any?(& &1 == "Simple")
      true

      iex> TestTalon.Talon.talon_resource("simples")
      TestTalon.Talon.Simple

      iex> TestTalon.Talon.talon_resource(TestTalon.Simple)
      TestTalon.Talon.Simple

      iex> TestTalon.Talon.talon_resource(%TestTalon.Simple{})
      TestTalon.Talon.Simple

      iex> TestTalon.Talon.controller_action("simples")
      {TestTalon.Simple, :simples, "admin-lte"}

      iex> TestTalon.Talon.base()
      TestTalon

      iex> TestTalon.Talon.template_path_name("simples")
      "simple"
  """

  require Talon.Config, as: Config

  defmacro __using__(opts) do
    Code.ensure_compiled(Talon.Config)
    otp_app = opts[:otp_app]
    unless otp_app do
      raise "Must provide :otp_app option"
    end

    repo = opts[:repo]

    quote location: :keep do
      require Talon.Config, as: Config

      @__resources__  Config.resources(__MODULE__)

      @__resource_map__  for mod <- @__resources__, into: %{},
        do: {Module.split(mod) |> List.last() |> to_string |> Inflex.underscore |> Inflex.Pluralize.pluralize, mod}

      @__view_path_names__ for {plural, _} <- @__resource_map__, into: %{}, do: {plural, Inflex.singularize(plural)}

      # @__resource_to_talon__ for resource <- @__resources__, do: {resource.schema(), resource}

      # @__base__ Module.split(__MODULE__) |> hd |> Module.concat(nil)
      @__base__ Config.module()

      @__repo__ unquote(repo) || Config.repo(__MODULE__)

      @__router__ Config.router(__MODULE__)

      @__router_helpers__ Module.concat(@__router__, Helpers)

      @__endpoint__ Config.endpoint(__MODULE__)

      @__resource_path_fn__ ((__MODULE__
        |> Module.split
        |> List.last
        |> Inflex.underscore) <>
        "_resource_path") |> String.to_atom

      @spec base() :: atom
      def base, do: @__base__

      @spec repo() :: atom
      def repo, do: @__repo__

      def resource_map, do: @__resource_map__

      def resources, do: @__resources__

      def resource_names, do: @__resource_map__ |> Map.keys

      def schema(resource_name) do
        try do
          talon_resource(resource_name).schema()
        rescue
          _ -> nil
        end
      end

      def schema_names do
        resource_names()
        |> Enum.map(fn name ->
          name |> schema |> Module.split |> List.last
        end)
      end

      def talon_resource(resource_name) when is_binary(resource_name) do
        @__resource_map__[resource_name]
      end
      def talon_resource(struct) when is_atom(struct) do
        with {_, resource} <- Enum.find(@__resources__, &(struct == &1.schema())), do: resource
      end
      def talon_resource(resource) when is_map(resource) do
        talon_resource(resource.__struct__)
      end

      def resource_schema(resource_name) when is_binary(resource_name) do
        {String.to_atom(resource_name), talon_resource(resource_name)}
      end

      def controller_action(resource_name) do
        {resource_name, talon_resource} = resource_schema(resource_name)
        schema = talon_resource.schema()
        {schema, resource_name, Application.get_env(:talon, :theme)}
      end

      def template_path_name(resource_name) do
        @__view_path_names__[resource_name]
      end

      @doc """
      Look update field type overrides
      """
      @spec schema_field_type(Module.t | Struct.t, atom, atom) :: atom
      def schema_field_type(schema, field, type) do
        talon_resource = talon_resource(schema)
        Keyword.get(talon_resource.schema_types(), field, type)
      end

      def primary_key(schema) do
        Map.get schema, talon_resource(schema).adapter().primary_key(schema)
      end

      @doc """
      Retrieve the name value form a model.

      ## Examples

          %TestTalon.Talon.Noid{description: "test", company: "Acme"} |>
          Talon.Context.display_name()
          Acme
      """
      def display_name(schema) do
        talon_resource = talon_resource(schema)
        if function_exported?(talon_resource, :display_name, 1) do
          talon_resource.display_name(schema)
        else
          Map.get schema, talon_resource.name_field()
        end
      end

      @doc """

      ## Examples:

          iex> Talon.Utils.resource_path(TestTalon.Product)
          "/talon/products"

          iex> Talon.Utils.resource_path(%TestTalon.Product{})
          "/talon/products/new"

          iex> Talon.Utils.resource_path(%TestTalon.Product{id: 1})
          "/talon/products/1"

          iex> Talon.Utils.resource_path(%TestTalon.Product{id: 1}, :edit)
          "/talon/products/1/edit"

          iex> Talon.Utils.resource_path(%TestTalon.Product{id: 1}, :update)
          "/talon/products/1"

          iex> Talon.Utils.resource_path(%TestTalon.Product{id: 1}, :destroy)
          "/talon/products/1"

          iex> Talon.Utils.resource_path(TestTalon.Product, :create)
          "/talon/products"

          iex> Talon.Utils.resource_path(TestTalon.Product, :batch_action)
          "/talon/products/batch_action"

          iex> Talon.Utils.resource_path(TestTalon.Product, :csv)
          "/talon/products/csv"

          iex> Talon.Utils.resource_path(%Plug.Conn{assigns: %{resource: %TestTalon.Product{}}}, :index, [[scope: "active"]])
          "/talon/products?scope=active"
      """
      def resource_path(schema, action, opts \\ [])
      def resource_path(%{} = schema, action, opts) do
        # route_path = Talon.Resource.talon_resource(schema).route_name()
        route_path = talon_resource(schema).route_name()
        apply @__router_helpers__, @__resource_path_fn__, [@__endpoint__, action,
          route_path, primary_key(schema) | opts]
      end
      def resource_path(schema_mod, action, opts) when is_atom(schema_mod) do
        # IO.inspect action, label: "action"
        # IO.inspect opts, label: "opts"
        route_path = talon_resource(schema_mod).route_name()
        # route_path = Talon.Resource.talon_resource(schema_mod).route_name()
        apply @__router_helpers__, @__resource_path_fn__, [@__endpoint__,
          action, route_path | opts]
      end
      # def router_helpers, do: @__router_helpers__
      # def resource_path_fn, do: @__resource_path_fn__
      # def endpoint
      def nav_action_links(conn) do
        Talon.Concern.nav_action_links(__MODULE__,
          Phoenix.Controller.action_name(conn), conn.assigns.resource)
      end

      defoverridable [
        base: 0, repo: 0, resource_map: 0, schema: 1, schema_names: 0,
        talon_resource: 1, resource_path: 3, resource_schema: 1,
        controller_action: 1, template_path_name: 1, schema_field_type: 3,
        nav_action_links: 1
      ]
    end

  end

  @doc """
  Return the action likes for a given controller action and resource.

  Returns a list of action link tuples for give page and scema resource.

  Note: This function is overridable
  """
  @spec nav_action_links(atom, atom, Struct.t | Module.t) :: List.t
  def nav_action_links(concern, action, resource) when action in [:index, :edit] do
    [nav_action_link(concern, :new, resource)]
  end
  def nav_action_links(concern, :show, resource) do
    [
      nav_action_link(concern, :edit, resource),
      nav_action_link(concern, :new, resource),
      nav_action_link(concern, :delete, resource)
    ]
  end
  def nav_action_links(_concern, _action, _resource) do
    []
  end

  @spec nav_action_links(Plug.Conn.t) :: List.t
  def nav_action_links(conn) do
    conn.assigns.talon.concern.nav_action_links(conn)
  end

  @doc """
  Return the action link tuple for an action link

  Returns the action link for `:new`, `:edit`, and `:delete` actions.

  ## Examples

      iex> Talon.Concern.nav_action_link(TestTalon.Talon, :new, TestTalon.Simple)
      {:new, "New Simple", "/talon/simples/new"}

      iex> Talon.Concern.nav_action_link(TestTalon.Talon, :new, %TestTalon.Simple{id: 1})
      {:new, "New Simple", "/talon/simples/new"}

      iex> Talon.Concern.nav_action_link(TestTalon.Talon, :edit, %TestTalon.Simple{id: 1})
      {:edit, "Edit Simple", "/talon/simples/1/edit"}

      iex> Talon.Concern.nav_action_link(TestTalon.Talon, :delete, %TestTalon.Simple{id: 1})
      {:delete, "Delete Simple", "/talon/simples/1"}
  """
  @spec nav_action_link(atom, atom, atom | struct) :: {atom, String.t, String.t}
  def nav_action_link(concern, action, resource_or_module) do
    {resource, module} =
      case resource_or_module do
        %{__struct__: module} -> {resource_or_module, module}
        module -> {module.__struct__, module}
      end
      # |> IO.inspect(label: "...{resource, module}")
    path =
      case action do
        :new -> concern.resource_path(module, :new)
        :edit -> concern.resource_path(resource, :edit)
        :delete -> concern.resource_path(resource, :delete)
      end
      # |> IO.inspect(label: "...path")
    title = String.capitalize(to_string(action)) <> " " <> Talon.Utils.titleize(resource)
    {action, title, path}
  end

  @doc """
  Return the app's base module.

  ## Examples

      iex> Talon.app_module(TestTalon.Talon)
      TestTalon
  """
  @spec app_module(atom) :: atom
  def app_module(talon) do
    talon.base()
  end

  @spec web_namespace() :: Module.t | nil
  def web_namespace do
    Config.web_namespace()
  end

  def web_namespace(conn) do
    conn.assigns.talon.web_namespace
  end

  @spec web_path() :: String.t
  def web_path do
    case web_namespace() do
      nil -> "web"
      _ ->
        Path.join(["lib", Inflex.underscore(Config.module()), "web"])
    end
  end

  def concern(conn) do
    conn.assigns.talon.talon
  end

  @doc """
  Returns a list of links for each of the Talon managed resources.

  Note: This function is overridable
  """
  @spec resource_paths(Plug.Conn.t) :: [Tuple.t]
  def resource_paths(conn) do
    concern = concern(conn)
    concern.resources()
    |> Enum.map(fn talon_resource ->
      schema = talon_resource.schema()
      {Talon.Utils.titleize(schema) |> Inflex.Pluralize.pluralize, concern.resource_path(schema, :index)}
    end)
  end


  def resource_path(conn, action_or_resource, opts_or_action, opts \\ [])
  def resource_path(conn, action, opts, _) when is_atom(action) do
    concern(conn).resource_path(conn.assigns.resource, action, opts)
  end
  def resource_path(conn, resource, action, opts) do
    concern(conn).resource_path(resource, action, opts)
  end

end
