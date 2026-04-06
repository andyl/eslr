defmodule Elr.MixProject do
  use Mix.Project

  @version "0.0.3"

  def project do
    [
      app: :elr,
      version: @version,
      elixir: "~> 1.19",
      start_permanent: Mix.env() == :prod,
      description: "Elixir Load & Run",
      escript: [main_module: Elr.CLI],
      usage_rules: usage_rules(),
      package: package(),
      docs: docs(),
      deps: deps()
    ]
  end

  def application do
    [
      extra_applications: [:logger, :inets, :ssl]
    ]
  end

  defp deps do
    [
      # Utilities
      {:igniter, "~> 0.6", only: [:dev, :test]},
      {:jason, "~> 1.4"},
      {:yaml_elixir, "~> 2.9"},
      # AI Tooling
      {:usage_rules, "~> 1.2", only: [:dev, :test]},
      # Conventional Commits, Releases
      {:commit_hook, "~> 0.4"},
      {:git_ops, "~> 2.0", only: [:dev, :test], runtime: false},
      # Documentation
      {:ex_doc, "~> 0.31", only: :dev, runtime: false}
    ]
  end

  defp usage_rules do
    [
      file: "RULES.md",
      usage_rules: [{~r/.*/, link: :markdown}],
      skills: [
        location: ".claude/skills",
        build: []
      ]
    ]
  end

  defp package do
    [
      name: "erl",
      licenses: ["MIT"],
      links: %{
        "GitHub" => "https://github.com/andyl/erl",
        "Docs" => "https://hexdocs.pm/erl"
      },
      files: ~w(lib priv mix.exs README.md CHANGELOG.md LICENSE)
    ]
  end

  defp docs do
    [
      main: "overview",
      logo: "assets/logo.svg",
      favicon: "assets/favicon.svg",
      source_url: "https://github.com/andyl/elr",
      source_ref: "v#{@version}",
      extras: [
        {"README.md", title: "Overview", filename: "overview"},
        "LICENSE"
      ]
    ]
  end
end
