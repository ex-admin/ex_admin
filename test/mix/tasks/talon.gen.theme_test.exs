Code.require_file "../../mix_helpers.exs", __DIR__

defmodule Mix.Tasks.Talon.Gen.ThemeTest do
  use ExUnit.Case
  import MixHelper

  alias Mix.Tasks.Talon.Gen.Theme, as: GenTheme

  @phx_web_path "lib/blogger/web"
  @phoenix_web_path "web"

  @phx_assets_path "assets"
  @phoenix_assets_path Path.join("web", "static")

  # @default_phx_config %{
  #   base: "Blogger",
  #   binding: [
  #     alias: "Blogger",
  #     human: "Blogger",
  #     base: "Blogger",
  #     web_module: "Blogger.Web",
  #     module: "Blogger.Blogger",
  #     scoped: "Blogger",
  #     singular: "blogger",
  #     path: "blogger"
  #   ],
  #   boilerplate: true,
  #   web_path: "lib/blogger/web",
  #   dry_run: nil,
  #   resource: "Blog",
  #   scoped_resource: "Blogs.Blog",
  #   themes: ["admin_lte"],
  #   project_structure: :phx,
  #   verbose: false,
  #   lib_path: "lib/blogger",
  #   web_namespace: "Web."
  # }

  # @default_phoenix_config Enum.into([web_path: "web", scoped_resource: "Blog",
  #   project_structure: :phoenix, web_namespace: ""], @default_phx_config)

  setup do
    {:ok, parsed: ~w(admin_lte admin_lte)}
  end

  describe "phx 1.3 structure" do
    test "new_1.3" do
      in_tmp "new_1.3", fn ->
        mk_web_path()
        mk_assets_path()
        GenTheme.run ~w(admin_lte admin_lte) ++ [~s(--web-path=lib/blogger/web), "--verbose", "--phx"]
        assert_file assets_path("static/images/talon/admin_lte/orderable.png")
        assert_file "assets/css/talon/admin-lte/talon.css"
        assert_file "assets/vendor/talon/admin-lte/bootstrap/css/bootstrap.min.css"
        assert_file "lib/blogger/web/templates/talon/admin_lte/layout/app.html.slim"
        assert_file "lib/blogger/web/views/talon/admin_lte/layout_view.ex", fn file ->
          file =~ "defmodule AdminLte.Web.LayoutView do"
          file =~ ~s(use Talon.Web, which: :view, theme: "admin_lte", module: AdminLte.Web)
        end
        assert_file "lib/blogger/web/templates/talon/admin_lte/generators/index.html.eex", fn file ->
          assert file =~ ~s(= AdminLte.Web.DatatableView.render_table)
        end
        assert_file "lib/blogger/web/templates/talon/admin_lte/components/datatable/datatable.html.slim", fn file ->
          assert file =~ ~s(= AdminLte.Web.PaginateView.paginate)
        end
      end

    end

    @name "all_default_opts"
    test @name, %{parsed: parsed} do
      # {bin_opts, opts, parsed}
      in_tmp @name, fn ->
        mk_web_path()
        config = GenTheme.do_config {[phx: true], [], parsed}
        Enum.each ~w(brunch assets layouts generators components)a, fn option ->
          assert config[option]
        end
      end
    end

    for opt <- ~w(brunch assets layouts generators components)a do
      @name "disable #{inspect opt}"
      @opt opt
      test @name, %{parsed: parsed} do
        # {bin_opts, opts, parsed}
        in_tmp @name, fn ->
          mk_web_path()
          config = GenTheme.do_config {[{@opt, false} | [phx: true]], [], parsed}
          Enum.each ~w(brunch assets layouts generators components)a, fn option ->
            if option == @opt do
              refute config[option]
            else
              assert config[option]
            end
          end
        end
      end
    end

    for opt <- ~w(brunch assets layouts generators components)a do
      @name "#{inspect opt}-only options"
      @opt opt
      test @name, %{parsed: parsed} do
        # {bin_opts, opts, parsed}
        in_tmp @name, fn ->
          mk_web_path()
          only_opt = {String.to_atom("#{@opt}_only"), true}
          config = GenTheme.do_config {[only_opt | [phx: true]], [], parsed}
          Enum.each ~w(brunch assets layouts generators components)a, fn option ->
            if option == @opt do
              assert config[option]
            else
              refute config[option]
            end
          end
        end
      end
    end

    test "brunch boilerplate appended", %{parsed: parsed} do
      in_tmp "brunch boilerplate appended", fn ->
        mk_web_path()
        mk_brunch_file(:phx)

        GenTheme.run  parsed ++ ["--proj-struct=phx", "--brunch-only"]

        assert_file brunch_file(:phx), fn file ->
          assert file =~ "'js/app.js': /^(js)|(node_modules)/,"
          assert file =~ "'js/talon/admin_lte/jquery-2.2.3.min.js': 'vendor/talon/admin-lte/plugins/jQuery/jquery-2.2.3.min.js',"

          assert file =~ "'css/app.css': /^(css)/,"
          assert file =~ "'css/talon/admin_lte/talon.css': ["
          assert file =~ "'css/talon/admin-lte/talon.css',"
        end
      end
    end
  end
  describe "phoenix structure" do
    test "brunch boilerplate appended", %{parsed: parsed} do
      in_tmp "brunch boilerplate appended phoenix", fn ->
        mk_web_path()
        mk_brunch_file(:phoenix)

        GenTheme.run  parsed ++ ["--proj-struct=phoenix", "--brunch-only"]

        assert_file brunch_file(:phoenix), fn file ->
          assert file =~ "'js/app.js': /^(web\\/static\\/js)|(node_modules)/,"
          assert file =~ "'js/talon/admin_lte/jquery-2.2.3.min.js': 'web/static/vendor/talon/admin-lte/plugins/jQuery/jquery-2.2.3.min.js',"

          assert file =~ "'css/app.css': /^(web\\/static\\/css)/,"
          assert file =~ "'css/talon/admin_lte/talon.css': ["
          assert file =~ "'web/static/css/talon/admin-lte/talon.css',"
        end
      end
    end

    test "new_phoenix" do
      in_tmp "new_phoenix", fn ->

        mk_web_path(@phoenix_web_path)
        mk_assets_path(@phoenix_assets_path)
        GenTheme.run ~w(admin_lte admin_lte) ++ [~s(--web-path=web), "--verbose", "--phoenix"]
        assert_file assets_path("assets/images/talon/admin_lte/orderable.png", :phoenix)
        assert_file "web/static/css/talon/admin-lte/talon.css"
        assert_file "web/static/vendor/talon/admin-lte/bootstrap/css/bootstrap.min.css"
        assert_file "web/templates/talon/admin_lte/layout/app.html.slim"
        assert_file "web/views/talon/admin_lte/layout_view.ex", fn file ->
          file =~ "defmodule AdminLte.LayoutView do"
          file =~ ~s(use Talon.Web, which: :view, theme: "admin_lte", module: AdminLte)
        end
        assert_file "web/templates/talon/admin_lte/generators/index.html.eex", fn file ->
          assert file =~ ~s(= AdminLte.DatatableView.render_table)
        end
        assert_file "web/templates/talon/admin_lte/components/datatable/datatable.html.slim", fn file ->
          assert file =~ ~s(= AdminLte.PaginateView.paginate)
        end
      end
    end
  end

  test "add compiler", %{parsed: parsed} do
    in_tmp "add_compiler", fn ->
      File.write "mix.exs", mix_exs()
      opts =
        parsed ++
        (~w(brunch assets layouts generators components)
        |> Enum.map(& "--no-#{&1}"))

      GenTheme.run opts ++ [~s(--web-path=web), "--phoenix"]
      assert_file "mix.exs", fn file ->
        assert file =~ "compilers: [:talon, :phoenix, :gettext] ++ Mix.compilers,"
      end
    end
  end

  #################
  # Helpers

  defp mix_exs, do: """
    defmodule Blogger.Mixfile do
      use Mix.Project

      def project do
        [app: :blogger,
         version: "0.0.1",
         elixir: "~> 1.4",
         elixirc_paths: elixirc_paths(Mix.env),
         compilers: [:phoenix, :gettext] ++ Mix.compilers,
         start_permanent: Mix.env == :prod,
         aliases: aliases(),
         deps: deps()]
      end
    end
    """
  # defp web_path(path, which \\ :phx)
  # defp web_path(path, :phx), do: Path.join(@phx_web_path, path)
  # defp web_path(path, _), do: Path.join(@phoenix_web_path, path)

  defp assets_path(path, which \\ :phx)
  defp assets_path(path, :phx), do: Path.join(@phx_assets_path, path)
  defp assets_path(path, _), do: Path.join(@phoenix_assets_path, path)

  defp brunch_path(:phx), do: "assets"
  defp brunch_path(_), do: ""

  defp mk_web_path(path \\ @phx_web_path) do
    File.mkdir_p!(path)
  end

  defp mk_assets_path(path \\ @phx_assets_path) do
    File.mkdir_p!(path)
  end

  # defp phoenix_config(opts \\ []) do
  #   Enum.into opts, @default_phoenix_config
  # end

  # defp phx_config(opts \\ []) do
  #   Enum.into opts, @default_phx_config
  # end

  @brunch_file """
  // Test brunch-config.js file

  """
  defp mk_brunch_file(mode) do
    path = brunch_path(mode)
    File.mkdir_p path
    File.write brunch_file(mode), @brunch_file
  end

  defp brunch_file(mode) do
    mode
    |> brunch_path
    |> Path.join("brunch-config.js")
  end

end
