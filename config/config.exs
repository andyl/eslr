import Config

config :git_ops,
  mix_project: Mix.Project.get!(),
  types: [tidbit: [hidden?: true], important: [header: "Important Changes"]],
  github_handle_lookup?: false,
  version_tag_prefix: "v",
  manage_mix_version?: true,
  manage_readme_version: true

if File.exists?(Path.expand("#{config_env()}.exs", __DIR__)) do
  import_config "#{config_env()}.exs"
end
