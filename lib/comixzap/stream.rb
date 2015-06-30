require 'json'

module ComixZap
  class Stream
    def initialize stream
      @stream = stream
    end

    def self.json_stream stream
      self.new stream
    end

    def << val
      @stream.write "#{val.to_json}\r\n"  
    end
  end
end
