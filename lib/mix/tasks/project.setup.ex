defmodule Mix.Tasks.Project.Setup.Docs do
  @moduledoc false
  def short_doc, do: "Complete project setup with environment variables and configuration"
  def example, do: "mix project.setup"
  
  def long_doc do
    """
    #{short_doc()}

    This task configures a new Phoenix/LiveView/Ash project with:
    - Cldr module (required for ex_money)
    - Environment variables for database in config/dev.exs
    - LiveDebugger port configuration
    - .env.example file
    - .tool-versions file
    - .gitignore updates for .env files

    ## Example

    ```sh
    #{example()}
    ```

    Run this after creating a project with `mix igniter.new` (without --setup flag).
    """
  end
end

if Code.ensure_loaded?(Igniter) do
  defmodule Mix.Tasks.Project.Setup do
    @shortdoc "#{__MODULE__.Docs.short_doc()}"
    @moduledoc __MODULE__.Docs.long_doc()
    use Igniter.Mix.Task

    def info(_argv, _composing_task) do
      %Igniter.Mix.Task.Info{
        group: :project,
        # Compose usage_rules.sync if needed
        composes: []
      }
    end

    def igniter(igniter) do
      app_name = Igniter.Project.Application.app_name(igniter)
      cldr_module = Igniter.Project.Module.module_name(igniter, "Cldr")
      has_ex_cldr = Igniter.Project.Deps.has_dep?(igniter, :ex_cldr)

      igniter
      |> maybe_create_cldr_module(cldr_module, has_ex_cldr)
      |> maybe_configure_cldr_backend(cldr_module, has_ex_cldr)
      |> configure_database_env_vars(app_name)
      |> configure_live_debugger_port()
      |> create_env_example(app_name)
      |> create_tool_versions()
      |> update_gitignore()
    end

    defp maybe_create_cldr_module(igniter, _cldr_module, false), do: igniter
    
    defp maybe_create_cldr_module(igniter, cldr_module, true) do
      Igniter.Project.Module.find_and_update_or_create_module(
        igniter,
        cldr_module,
        """
        use Cldr,
          locales: ["en"],
          default_locale: "en"
        """,
        fn zipper -> {:ok, zipper} end
      )
    end

    defp maybe_configure_cldr_backend(igniter, _cldr_module, false), do: igniter
    
    defp maybe_configure_cldr_backend(igniter, cldr_module, true) do
      Igniter.Project.Config.configure_new(
        igniter,
        "config.exs",
        :ex_cldr,
        [:default_backend],
        cldr_module
      )
    end

    defp configure_database_env_vars(igniter, app_name) do
      app_module = Igniter.Project.Module.module_name(igniter, "")
      repo_module = Module.concat(app_module, Repo)

      igniter
      |> Igniter.Project.Config.configure(
        "dev.exs",
        app_name,
        [repo_module, :username],
        {:code, Sourceror.parse_string!(~s[System.get_env("DB_USERNAME") || "postgres"])}
      )
      |> Igniter.Project.Config.configure(
        "dev.exs",
        app_name,
        [repo_module, :password],
        {:code, Sourceror.parse_string!(~s[System.get_env("DB_PASSWORD") || "postgres"])}
      )
      |> Igniter.Project.Config.configure(
        "dev.exs",
        app_name,
        [repo_module, :hostname],
        {:code, Sourceror.parse_string!(~s[System.get_env("DB_HOSTNAME") || "localhost"])}
      )
      |> Igniter.Project.Config.configure(
        "dev.exs",
        app_name,
        [repo_module, :database],
        {:code, Sourceror.parse_string!(~s[System.get_env("DB_NAME") || "#{app_name}_dev"])}
      )
    end

    defp configure_live_debugger_port(igniter) do
      igniter
      |> Igniter.Project.Config.configure_new(
        "dev.exs",
        :live_debugger,
        [:enabled],
        true
      )
      |> Igniter.Project.Config.configure_new(
        "dev.exs",
        :live_debugger,
        [:port],
        {:code, Sourceror.parse_string!(~s[String.to_integer(System.get_env("LIVE_DEBUGGER_PORT") || "4008")])}
      )
    end

    defp create_env_example(igniter, app_name) do
      content = """
      # Development environment variables
      # Copy this file to .env and customize for your local environment

      # Port for the Phoenix server (default: 4000)
      # Use different ports for different projects to run them simultaneously
      export PORT=4001

      # LiveDebugger port (default: 4008)
      export LIVE_DEBUGGER_PORT=4009

      # Database configuration (defaults to postgres/postgres/localhost if not set)
      # export DB_USERNAME=postgres
      # export DB_PASSWORD=postgres
      # export DB_HOSTNAME=localhost
      # export DB_NAME=#{app_name}_dev
      """

      Igniter.create_new_file(igniter, ".env.example", content)
    end

    defp create_tool_versions(igniter) do
      Igniter.create_new_file(igniter, ".tool-versions", "ruby 3.3.6\n")
    end

    defp update_gitignore(igniter) do
      Igniter.update_file(igniter, ".gitignore", fn zipper ->
        source = Sourceror.Zipper.node(zipper) |> Sourceror.to_string()

        if String.contains?(source, ".env") do
          {:ok, zipper}
        else
          updated_source = source <> "\n# Environment variables\n.env\n.envrc\n"
          new_quoted = Sourceror.parse_string!(updated_source)
          {:ok, Sourceror.Zipper.replace(zipper, new_quoted)}
        end
      end)
    end
  end
end
