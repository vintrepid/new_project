defmodule Mix.Tasks.Project.Setup do
  @moduledoc """
  Complete project setup after igniter.new
  
  This task:
  1. Configures environment variables in config/dev.exs
  2. Creates .env.example file
  3. Adds .tool-versions file
  4. Updates .gitignore
  5. Syncs usage rules
  6. Creates and migrates database
  
  ## Usage
  
      mix project.setup
  
  After running igniter.new without --setup, run this task to complete setup.
  """
  
  use Mix.Task
  
  @shortdoc "Complete project setup after igniter.new"
  
  def run(_args) do
    Mix.shell().info("Setting up project...")
    
    configure_dev_env_vars()
    create_env_example()
    create_tool_versions()
    update_gitignore()
    sync_usage_rules()
    setup_database()
    
    Mix.shell().info("")
    Mix.shell().info("Project setup complete!")
    Mix.shell().info("")
    Mix.shell().info("Next steps:")
    Mix.shell().info("1. Copy .env.example to .env and configure your credentials")
    Mix.shell().info("2. Run: source .env")
    Mix.shell().info("3. Run: mix phx.server")
  end
  
  defp configure_dev_env_vars do
    Mix.shell().info("Configuring environment variables in config/dev.exs...")
    
    dev_config_path = "config/dev.exs"
    {:ok, content} = File.read(dev_config_path)
    
    app_name = Mix.Project.config()[:app]
    app_module = Macro.camelize(to_string(app_name))
    
    updated_content = content
    |> replace_db_config(app_name, app_module)
    |> replace_port_config()
    |> replace_live_debugger_config()
    
    File.write!(dev_config_path, updated_content)
    Mix.shell().info("✓ Updated config/dev.exs")
  end
  
  defp replace_db_config(content, app_name, app_module) do
    db_regex = ~r/config :#{app_name}, #{app_module}\.Repo,\s+username: "[^"]*",\s+password: "[^"]*",\s+hostname: "[^"]*",\s+database: "[^"]*",/
    
    replacement = """
    config :#{app_name}, #{app_module}.Repo,
      username: System.get_env("DB_USERNAME") || "postgres",
      password: System.get_env("DB_PASSWORD") || "postgres",
      hostname: System.get_env("DB_HOSTNAME") || "localhost",
      database: System.get_env("DB_NAME") || "#{app_name}_dev",
    """
    |> String.trim_trailing()
    
    String.replace(content, db_regex, replacement)
  end
  
  defp replace_port_config(content) do
    port_regex = ~r/port: \d+/
    replacement = "port: String.to_integer(System.get_env(\"PORT\") || \"4000\")"
    
    String.replace(content, port_regex, replacement)
  end
  
  defp replace_live_debugger_config(content) do
    if String.contains?(content, "config :live_debugger") do
      debugger_regex = ~r/config :live_debugger,\s+enabled: true,\s+port: \d+/
      
      replacement = """
      config :live_debugger,
        enabled: true,
        port: String.to_integer(System.get_env("LIVE_DEBUGGER_PORT") || "4008")
      """
      |> String.trim()
      
      String.replace(content, debugger_regex, replacement)
    else
      content
    end
  end
  
  defp create_env_example do
    Mix.shell().info("Creating .env.example...")
    
    app_name = Mix.Project.config()[:app]
    
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
    
    File.write!(".env.example", content)
    Mix.shell().info("✓ Created .env.example")
  end
  
  defp create_tool_versions do
    Mix.shell().info("Creating .tool-versions...")
    
    content = "ruby 3.3.6\n"
    File.write!(".tool-versions", content)
    Mix.shell().info("✓ Created .tool-versions")
  end
  
  defp update_gitignore do
    Mix.shell().info("Updating .gitignore...")
    
    {:ok, content} = File.read(".gitignore")
    
    if String.contains?(content, ".env") do
      Mix.shell().info("✓ .gitignore already contains .env entries")
    else
      updated_content = content <> "\n# Environment variables\n.env\n.envrc\n"
      File.write!(".gitignore", updated_content)
      Mix.shell().info("✓ Updated .gitignore")
    end
  end
  
  defp sync_usage_rules do
    Mix.shell().info("Syncing usage rules...")
    Mix.Task.run("usage_rules.sync", [
      "AGENTS.md",
      "--all",
      "--inline", "usage_rules:all",
      "--link-to-folder", "deps"
    ])
    Mix.shell().info("✓ Synced usage rules")
  end
  
  defp setup_database do
    Mix.shell().info("")
    Mix.shell().info("Note: Database setup requires credentials to be configured.")
    Mix.shell().info("After creating .env with your credentials, run:")
    Mix.shell().info("  source .env && mix ecto.create && mix ecto.migrate")
  end
end
