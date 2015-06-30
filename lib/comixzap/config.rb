require 'yaml'
require 'comixzap/environment'
module ComixZap
  module Config
    class << self
      def load
        root_dir = ComixZap::Environment::ROOT_DIR
        File.open File.join(root_dir, 'config.yml') do |fh|
          YAML::load fh.read
        end
      end
    end
  end
end
