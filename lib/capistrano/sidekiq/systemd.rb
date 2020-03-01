require "capistrano/sidekiq/systemd/version"
load File.expand_path('../tasks/systemd.rake', __FILE__)

module Capistrano
  module Sidekiq
    module Systemd
      class Error < StandardError; end
      # Your code goes here...
    end
  end
end
