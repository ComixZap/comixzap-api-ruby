require 'uri'
require 'json'
require 'zlib'
require 'sinatra/base'
require 'sinatra/reloader'
require 'sinatra/config_file'
require 'sinatra/streaming'
require './lib/zip_reader.rb'

module ComixZap
    class MainApplication < Sinatra::Base

        register Sinatra::ConfigFile
        helpers Sinatra::Streaming

        configure :development do
            register Sinatra::Reloader
            also_reload './lib/zip_reader.rb'
        end

        set :file_root, File.dirname(__FILE__)
        config_file "#{settings.file_root}/config.yml"

        #statuses
        OK = 0
        ERR = 1

        # hooks
        before do
            @files_to_close = []
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
            path = File.join(settings.comics_root, directory)
            raise 'Path is not a directory' unless File.directory?(path)
            entries = Dir.entries(path).sort.map do |filename|
                full_path = File.join(path, filename)
                {
                    filename: filename,
                    size: File.size(full_path),
                    directory: File.directory?(full_path)
                }
            end.select do |entry|
                (entry[:filename] !~ /^\./) && (entry[:directory] || (entry[:filename] =~ /\.cbz$/i))
            end
            wrap_response(entries, OK, {directory: directory})
        end

        get '/comic/list' do
            content_type 'application/json'
            filename = params[:file]
            path = File.join(settings.comics_root, filename)
            raise 'File does not exist' unless File.file?(path)
            zip_file = ComixZap::ZipReader.new path
            zip_file.check_file
            entries = zip_file.entries
            zip_file.close
            wrap_response(entries, OK)
        end

        get '/comic/image' do
            filename = params[:file]
            offset = params[:offset].to_i

            path = File.join(settings.comics_root, filename)
            raise 'File does not exist' unless File.file?(path)
            zip_file = ComixZap::ZipReader.new path
            file_info = zip_file.file_info_at_offset offset

            content_type detect_mime(file_info[:filename])
            case file_info[:compressionType]
                when ComixZap::ZipReader::COMPRESSION_UNCOMPRESSED
                    stream do |out|
                        IO::copy_stream(zip_file.file, out, offset, file_info[:usize])
                    end
                when ComixZap::ZipReader::COMPRESSION_DEFLATE
                else
                    raise 'Unsupported compression type'
            end

            if accepts_encoding(request, 'gzip')
                # pass in raw string w/ gzip headers
                headers['content-encoding'] = 'gzip'
                stream do |out|
                    out.write ComixZap::ZipReader::gzip_header file_info
                    IO::copy_stream zip_file.file, out, file_info[:csize], file_info[:rawOffset]
                    out.write ComixZap::ZipReader::gzip_footer file_info
                    zip_file.close
                end
            else
                # inflate raw
                inflate = Zlib::Inflate.new(-15)
                stream do |out|
                    zip_file.file.seek(file_info[:rawOffset])
                    out.write inflate.inflate(zip_file.file.read(file_info[:csize]))
                    zip_file.close
                end
            end

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

        # check origin
        def check_origin origin
            return true unless origin
            origin_uri = URI(origin)
            origin_uri.host = origin if origin_uri.host.nil?
            settings.allowed_origins && settings.allowed_origins.any? do |allowed|
                allowed_uri = URI(allowed)
                allowed_uri.host = allowed if allowed_uri.host.nil?
                return false if allowed_uri.scheme && allowed_uri.scheme != origin_uri.scheme
                allowed_uri.host == origin_uri.host
            end
        end

        def accepts_encoding request, encoding
            accepted_encodings_text = request.env['HTTP_ACCEPT_ENCODING']
            return false unless accepted_encodings_text

            #accepted_encodings
            accepted_encodings_text.strip.split(/\s*,\s*/)
                .include?(encoding)
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

