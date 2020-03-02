namespace :load do
  task :defaults do
    set :sidekiq_monit_conf_dir, '/etc/monit/conf.d'
    set :sidekiq_monit_conf_file, "sidekiq-#{fetch(:stage)}.conf"
    set :sidekiq_monit_use_sudo, true
    set :monit_bin, '/usr/bin/monit'
    set :sidekiq_monit_default_hooks, true
    set :sidekiq_monit_group, nil
  end
end

namespace :deploy do
  before :starting, :check_sidekiq_monit_hooks do
    if fetch(:sidekiq_default_hooks) && fetch(:sidekiq_monit_default_hooks)
      invoke 'sidekiq:monit:add_default_hooks'
    end
  end
end

namespace :sidekiq do
  namespace :monit do
    task :add_default_hooks do
      before 'deploy:updating',  'sidekiq:monit:unmonitor'
      after  'deploy:published', 'sidekiq:monit:monitor'
    end

    desc 'Stop Sidekiq monit-service'
    task :stop do
      on roles(fetch(:sidekiq_roles)) do
        sidekiq_options_per_process.each_index do |index|
          sudo_if_needed "#{fetch(:monit_bin)} stop #{service_unit_name(index)}"
        end
      end
    end

    desc 'Start Sidekiq monit-service'
    task :start do
      on roles(fetch(:sidekiq_roles)) do
        sidekiq_options_per_process.each_index do |index|
          sudo_if_needed "#{fetch(:monit_bin)} start #{service_unit_name(index)}"
        end
      end
    end

    desc 'Restart Sidekiq monit-service'
    task :restart do
      on roles(fetch(:sidekiq_roles)) do
        sidekiq_options_per_process.each_index do |index|
          sudo_if_needed"#{fetch(:monit_bin)} restart #{service_unit_name(index)}"
        end
      end
    end

    desc 'Unmonitor Sidekiq monit-service'
    task :unmonitor do
      on roles(fetch(:sidekiq_roles)) do
        sidekiq_options_per_process.each_index do |index|
          begin
            sudo_if_needed "#{fetch(:monit_bin)} unmonitor #{service_unit_name(index)}"
          rescue
            # no worries here
          end
        end
      end
    end

    desc 'Monitor Sidekiq monit-service'
    task :monitor do
      on roles(fetch(:sidekiq_roles)) do
        sidekiq_options_per_process.each_index do |index|
          begin
            sudo_if_needed "#{fetch(:monit_bin)} monitor #{service_unit_name(index)}"
          rescue
            invoke 'sidekiq:monit:install'
            sudo_if_needed "#{fetch(:monit_bin)} monitor #{service_unit_name(index)}"
          end
        end
      end
    end

    desc 'Install Sidekiq monit-service'
    task :install do
      on roles(fetch(:sidekiq_roles)) do |role|
        template = File.read(File.expand_path('../../../../generators/capistrano/sidekiq/monit/templates/sidekiq.conf.capistrano.erb', __FILE__))
        upload!(StringIO.new(ERB.new(template).result(binding)), "#{fetch(:tmp_dir)}/monit.conf")
        sudo_if_needed "mv #{fetch(:tmp_dir)}/monit.conf #{fetch(:sidekiq_monit_conf_dir)}/#{fetch(:sidekiq_monit_conf_file)}"
        sudo_if_needed "#{fetch(:monit_bin)} reload"
      end
    end

    desc 'Uninstall Sidekiq monit-service'
    task :uninstall do
      on roles(fetch(:sidekiq_roles)) do |role|
        sudo_if_needed "rm #{fetch(:sidekiq_monit_conf_dir)}/#{fetch(:sidekiq_monit_conf_file)}"
        sudo_if_needed "#{fetch(:monit_bin)} reload"
      end
    end

    def sudo_if_needed(command)
      send(use_sudo? ? :sudo : :execute, command)
    end

    def use_sudo?
      fetch(:sidekiq_monit_use_sudo)
    end
  end
end
