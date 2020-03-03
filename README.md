# Capistrano::Sidekiq::Systemd

Sidekiq integration for Capistrano(`systemd` only).
Heavily influenced by https://github.com/seuros/capistrano-sidekiq.
Supports Multiple processes. Primarity should work on sidekiq version > 6.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'capistrano-sidekiq-systemd', require: false
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install capistrano-sidekiq-systemd

## Usage
```ruby
# Capfile
require 'capistrano/sidekiq/systemd'
require 'capistrano/sidekiq/monit' #to require monit tasks
```
Configurable options, shown here with defaults:

```ruby
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
# Bundler integration
set :bundle_bins, fetch(:bundle_bins).to_a.concat(%w[sidekiq])
# Options for single process setup
set :sidekiq_require, nil
set :sidekiq_tag, nil
set :sidekiq_queue, nil
set :sidekiq_config, nil
set :sidekiq_concurrency, nil
set :sidekiq_options, nil
# Monit options
set :sidekiq_monit_conf_dir, '/etc/monit/conf.d'
set :sidekiq_monit_conf_file, "sidekiq-#{fetch(:stage)}.conf"
set :sidekiq_monit_use_sudo, true
set :sidekiq_monit_max_mem, nil
set :monit_bin, '/usr/bin/monit'
set :sidekiq_monit_default_hooks, true
set :sidekiq_monit_group, nil
```

## Tasks

    cap sidekiq:install                # Generate and upload .service files
    cap sidekiq:quiet                  # Quiet sidekiq (stop fetching new tasks from Redis)
    cap sidekiq:restart                # Restart sidekiq
    cap sidekiq:start                  # Start sidekiq
    cap sidekiq:stop                   # Stop sidekiq
    cap sidekiq:monit:install          # Generate and upload monit.conf file
    cap sidekiq:monit:monitor          # Monitor Sidekiq monit-service
    cap sidekiq:monit:restart          # Restart Sidekiq monit-service
    cap sidekiq:monit:start            # Start Sidekiq monit-service
    cap sidekiq:monit:stop             # Stop Sidekiq monit-service
    cap sidekiq:monit:uninstall        # Uninstall Sidekiq monit-service
    cap sidekiq:monit:unmonitor        # Unmonitor Sidekiq monit-service

## Default hooks(systemd)

    after 'deploy:starting',  'sidekiq:quiet'
    after 'deploy:updated',   'sidekiq:stop'
    after 'deploy:published', 'sidekiq:start'
    after 'deploy:failed', 'sidekiq:restart'

By default all of these hooks are active. If you wish to remove them please set:

```ruby
set :sidekiq_default_hooks, false
```

## Default hooks(monit)

    before 'deploy:updating',  'sidekiq:monit:unmonitor'
    after  'deploy:published', 'sidekiq:monit:monitor'

By default all of these hooks are active. If you wish to remove them please set:

```ruby
set :sidekiq_monit_default_hooks, false
```


## Multiple processes

You can configure sidekiq to start with multiple processes. To configure each process please use `sidekiq_options_per_process`.
Example using different config files:

```ruby
set :sidekiq_options_per_process, [
    "--config config/sidekiq.yml",
    "--config config/sidekiq.yml",
    "--config config/sidekiq_mailer.yml"
]
```

Example using arbitrary options:

```ruby
set :sidekiq_options_per_process, [
    "--queue high --concurrency 2",
    "--queue default --concurrency 4 ",
]
```

Example using hash options and custom service_unit_name(Though it's not recommended to change `service_unit_name`):

```ruby
set :sidekiq_options_per_process, [
    { queue: 'high', concurrency: 2, service_unit_name: 'sidekiq-production-1' }
    { queue: 'default', concurrency: 4, service_unit_name: 'sidekiq-production-2' }
]
```

`Important!`
Please do not change `--tag` option if you want to use `monit` integration. By default it will be set to uniq `service_unit_name`, so monit will be able to identify sidekiq process.

## Memory limit(monit)
You can set memory limit for monit
```ruby
set :sidekiq_monit_max_mem, 3072
```
This will add `if totalmem is greater than 3072 MB for 2 cycles then restart` to monit.conf file. Don't forget to run `cap sidekiq:monit:install` any time you change `sidekiq_monit_max_mem` option.

## Memory limit(systemd)
There is an available option to set up memory limit for systemd.service:

You can set memory limit with:
```ruby
set :sidekiq_max_mem, '3072K'
```
This will add:

    MemoryAccounting=true
    MemoryLimit=3072K

Though i am not able to get it to work because we use `--user` to control systemd. TODO: Investigate.


## Configuring systemd
To generate and upload `.service` file please run:

    cap sidekiq:install

## Configuring monit
To generate and upload `.conf` file please run:

    cap sidekiq:monit:install

Please remember to add `require` to `Capfile`

```ruby
  require 'capistrano/sidekiq/monit' #to require monit tasks
```

If your deploy user has no need in `sudo` for using monit, you can disable it as follows:

```ruby
set :sidekiq_monit_use_sudo, false
```
## Development

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/spilin/capistrano-sidekiq-systemd. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [Contributor Covenant](http://contributor-covenant.org) code of conduct.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

## Code of Conduct

Everyone interacting in the Capistrano::Sidekiq::Systemd project’s codebases, issue trackers, chat rooms and mailing lists is expected to follow the [code of conduct](https://github.com/spilin/capistrano-sidekiq-systemd/blob/master/CODE_OF_CONDUCT.md).
