namespace :load do
  task :defaults do
    set :sidekiq_default_hooks, true
    set :sidekiq_env, -> { fetch(:rack_env, fetch(:rails_env, fetch(:stage))) }
    set :sidekiq_roles, fetch(:sidekiq_role, :app)
    set :sidekiq_options_per_process, nil
    set :sidekiq_user, nil
    set :sidekiq_max_mem, nil
    set :service_unit_name, "sidekiq-#{fetch(:stage)}.service"
    # Rbenv, Chruby, and RVM integration
    set :rbenv_map_bins, fetch(:rbenv_map_bins).to_a.concat(%w[sidekiq])
    set :rvm_map_bins, fetch(:rvm_map_bins).to_a.concat(%w[sidekiq])
    set :chruby_map_bins, fetch(:chruby_map_bins).to_a.concat(%w[sidekiq])
    # Options for single process setup
    set :sidekiq_require, nil
    set :sidekiq_tag, nil
    set :sidekiq_queue, nil
    set :sidekiq_config, nil
    set :sidekiq_concurrency, nil
    set :sidekiq_options, nil
  end
end

namespace :deploy do
  before :starting, :check_sidekiq_hooks do
    invoke 'sidekiq:add_default_hooks' if fetch(:sidekiq_default_hooks)
  end
end

namespace :sidekiq do
  task :add_default_hooks do
    after 'deploy:starting',  'sidekiq:quiet'
    after 'deploy:updated',   'sidekiq:stop'
    after 'deploy:published', 'sidekiq:start'
    after 'deploy:failed', 'sidekiq:restart'
  end

  desc 'Quiet sidekiq (stop fetching new tasks from Redis)'
  task :quiet do
    on roles fetch(:sidekiq_roles) do |role|
      switch_user(role) do
        sidekiq_options_per_process.each_index do |index|
          execute :systemctl, "--user", "reload", service_unit_name(index), raise_on_non_zero_exit: false
        end
      end
    end
  end

  desc 'Stop sidekiq (graceful shutdown within timeout, put unfinished tasks back to Redis)'
  task :stop do
    on roles fetch(:sidekiq_roles) do |role|
      switch_user(role) do
        sidekiq_options_per_process.each_index do |index|
          execute :systemctl, "--user", "stop", service_unit_name(index)
        end
      end
    end
  end

  desc 'Start sidekiq'
  task :start do
    on roles fetch(:sidekiq_roles) do |role|
      switch_user(role) do
        sidekiq_options_per_process.each_index do |index|
          execute :systemctl, "--user", "start", service_unit_name(index)
        end
      end
    end
  end

  desc 'Restart sidekiq'
  task :restart do
    invoke! 'sidekiq:stop'
    invoke! 'sidekiq:start'
  end

  desc 'Generate and upload .service files'
  task :install do
    on roles fetch(:sidekiq_roles) do |role|
      switch_user(role) do
        create_systemd_template(role)
        sidekiq_options_per_process.each_index do |index|
          execute :systemctl, "--user", "enable", service_unit_name(index)
        end
      end
    end
  end

  desc 'Uninstall .service files'
  task :uninstall do
    on roles fetch(:sidekiq_roles) do |role|
      switch_user(role) do
        sidekiq_options_per_process.each_index do |index|
          execute :systemctl, "--user", "disable", service_unit_name(index)
          execute :rm, File.join(fetch(:service_unit_path, File.join(capture(:pwd), ".config", "systemd", "user")),service_unit_name(index))
        end
      end
    end
  end

  def create_systemd_template(role)
    template = File.read(File.expand_path('../../../../generators/capistrano/sidekiq/systemd/templates/sidekiq.service.capistrano.erb', __FILE__))
    home_dir = capture :pwd
    systemd_path = fetch(:service_unit_path, File.join(home_dir, ".config", "systemd", "user"))
    sidekiq_cmd = SSHKit.config.command_map[:sidekiq].gsub('~', home_dir)
    execute :mkdir, "-p", systemd_path
    sidekiq_options_per_process.each_index do |index|
      upload!(StringIO.new(ERB.new(template).result(binding)), "#{systemd_path}/#{service_unit_name(index)}")
    end
    execute :systemctl, "--user", "daemon-reload"
  end

  def process_options(index = 0)
    args = []
    args.push "--environment #{fetch(:sidekiq_env)}"
    %w{require tag queue config concurrency}.each do |option|
      options = fetch(:sidekiq_options_per_process)&.[](index)
      Array((options.is_a?(Hash) && options[option.to_sym]) || fetch(:"sidekiq_#{option}")).each do |value|
        args.push "--#{option} #{value}"
      end
    end
    if (process_options = fetch(:sidekiq_options_per_process)&.[](index)).is_a?(String)
      args.push process_options
    end
    # use sidekiq_options for special options
    options = fetch(:sidekiq_options_per_process)&.[](index)
    Array((options.is_a?(Hash) && options[:sidekiq_options]) || fetch(:sidekiq_options)).each do |value|
      args.push value
    end
    args.compact.join(' ')
  end

  def switch_user(role)
    su_user = sidekiq_user(role)
    if su_user == role.user
      yield
    else
      as su_user do
        yield
      end
    end
  end

  def sidekiq_user(role)
    properties = role.properties
    properties.fetch(:sidekiq_user) || # local property for sidekiq only
      fetch(:sidekiq_user) ||
      properties.fetch(:run_as) || # global property across multiple capistrano gems
      role.user
  end

  def sidekiq_options_per_process
    fetch(:sidekiq_options_per_process) || [nil]
  end

  def service_unit_name(index)
    if multiple_processes?
      options = fetch(:sidekiq_options_per_process)&.[](index)
      (options.is_a?(Hash) && options[:service_unit_name]) || fetch(:service_unit_name).gsub(/(.*)\.service/, "\\1-#{index}.service")
    else
      fetch(:service_unit_name)
    end
  end

  def max_mem(index)
    if multiple_processes?
      options = fetch(:sidekiq_options_per_process)&.[](index)
      (options.is_a?(Hash) && options[:sidekiq_max_mem]) || fetch(:sidekiq_max_mem)
    else
      fetch(:sidekiq_max_mem)
    end
  end

  def multiple_processes?
    fetch(:sidekiq_options_per_process) && fetch(:sidekiq_options_per_process).size > 1
  end
end
