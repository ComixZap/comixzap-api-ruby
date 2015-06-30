require 'pathname'

module ComixZap
  module Environment
    ROOT_DIR = Pathname.new(__FILE__).parent.parent.parent

    def root_dir
      ROOT_DIR
    end

    def lib_dir
      @lib_dir ||= File.join(ROOT_DIR, 'lib')
    end

    class << self
      include Environment

      def setup!
        $: << lib_dir unless $:.include? lib_dir
      end
    end
  end
end
