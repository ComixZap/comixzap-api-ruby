require 'uri'
require 'json'
require 'sinatra/base'
require 'sinatra/streaming'

module ComixZap
  class Server < Sinatra::Base

    helpers Sinatra::Streaming

    #statuses
    OK = 0
    ERR = 1

    set :config, ComixZap::Config::load.symbolize_keys

    def comics_root
      settings.config[:comics_root]
    end

    def allowed_origins
      settings.config[:allowed_origins]
    end

    # hooks
    before do
      # apply headers if origin is valid, halt otherwise
      origin = request.env['HTTP_ORIGIN']
      return unless origin
      if check_origin(origin)
        headers['Access-Control-Allow-Origin'] = origin
      else
        halt
      end
    end

    # routes
    get '/file-list' do
      content_type 'application/json'
      directory = params[:directory] || ''
      streamable = params[:streamable] == 'true'
      path = File.join(comics_root, directory)
      raise 'Path is not a directory' unless File.directory?(path)
      if streamable 
        stream_response OK, {directory: directory} do |stream|
          begin
            ComixZap::Reader::directory(path) do |entry|
              stream << entry
            end
          rescue Exception => e
            stream << {status: ERR, message: e}
          end
        end
      else
        entries = ComixZap::Reader::directory(path)
        wrap_response(entries, OK, {directory: directory})
      end
    end

    get '/comic/list' do
      content_type 'application/json'
      filename = params[:file]
      streamable = params[:streamable] == 'true'
      path = File.join(comics_root, filename)
      raise 'File does not exist' unless File.file?(path)
      cache_control :public, :must_revalidate
      last_modified File.mtime(path)
      if streamable
        stream_response OK do |stream|
          begin
            ComixZap::Reader::list_archive_files(path) do |entry|
              stream << entry
            end
          rescue Exception => e
            stream << {status: ERR, message: e}
          end
        end
      else
        entries = ComixZap::Reader::list_archive_files(path)
        wrap_response(entries, OK)
      end
    end

    get '/comic/image' do
      filename = params[:file]
      offset = params[:offset].to_i
      extract_file = params[:extract_file]

      path = File.join(comics_root, filename)
      raise 'File does not exist' unless File.file?(path)
      cache_control :public, :must_revalidate
      last_modified File.mtime(path)
      unless extract_file
        extract_file = ComixZap::Reader::file_at_offset path, offset
      end
      content_type detect_mime(extract_file)
      ComixZap::Reader::extract_file path, extract_file
    end

    not_found do
      content_type 'text/plain'
      'Not found.'
    end

    error do
      wrap_response(nil , ERR, {message: env['sinatra.error'].message})
    end

    # wraps json response
    def wrap_response data, status = OK, meta = {}
      # keep the order status, meta, data
      return ({status: status})
        .merge(meta)
        .merge({data: data})
        .to_json
    end

    def stream_response status = OK, meta = {}, &block
      content_type 'application/json; boundary=CRNL'
      json_header = {status: status}.merge(meta)
      stream do |out|
        out.write "#{json_header.to_json}\r\n"
        json_stream = ComixZap::Stream.json_stream(out)
        yield json_stream
      end
    end

    # check origin
    def check_origin origin
      return true unless origin
      origin_uri = URI(origin)
      origin_uri.host = origin if origin_uri.host.nil?
      if allowed_origins.is_a?(Array)
        allowed_origins.any? do |allowed|
          allowed_uri = URI(allowed)
          allowed_uri.host = allowed if allowed_uri.host.nil?
          next false if allowed_uri.scheme && allowed_uri.scheme != origin_uri.scheme
          allowed_uri.host == origin_uri.host
        end
      end
    end

    def detect_mime filename
      case File.extname(filename).downcase
        when ".jpg"
          'image/jpeg'
        when ".jpeg"
          'image/jpeg'
        when ".gif"
          'image/gif'
        when ".png"
          'image/png'
      end
    end

    run! if app_file == $0
  end
end

