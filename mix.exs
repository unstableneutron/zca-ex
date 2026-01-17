defmodule ZcaEx.MixProject do
  use Mix.Project

  @version "0.1.0"
  @source_url "https://github.com/unstableneutron/zca-ex"

  def project do
    [
      app: :zca_ex,
      version: @version,
      elixir: "~> 1.17",
      name: "ZcaEx",
      description: "Unofficial Zalo API client for Elixir",
      source_url: @source_url,
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      elixirc_paths: elixirc_paths(Mix.env()),
      dialyzer: [plt_add_apps: [:mix]],
      package: package(),
      docs: docs()
    ]
  end

  def application do
    [
      extra_applications: [:logger, :crypto],
      mod: {ZcaEx.Application, []}
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp deps do
    [
      {:req, "~> 0.5"},
      {:mint_web_socket, "~> 1.0"},
      {:jason, "~> 1.4"},
      {:telemetry, "~> 1.2"},
      {:phoenix_pubsub, "~> 2.1", optional: true},
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false},
      {:ex_doc, "~> 0.30", only: :dev, runtime: false}
    ]
  end

  defp package do
    [
      name: "zca_ex",
      licenses: ["MIT"],
      links: %{"GitHub" => @source_url},
      files: ~w(lib .formatter.exs mix.exs README.md LICENSE docs)
    ]
  end

  defp docs do
    [
      main: "readme",
      extras: ["README.md"] ++ Path.wildcard("docs/*.md"),
      source_ref: "v#{@version}"
    ]
  end
end
