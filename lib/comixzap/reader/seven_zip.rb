module ComixZap
  module Reader
    module SevenZip
      class << self
        VALID_EXTENSIONS = %w{bmp jpg jpeg png gif}
        FILES_HEADER_REGEXP = /^(\s*-+)(\s+-+)(\s+-+)(\s+-+)(\s+)(.*)$/

        def extract_file archive_file, file_to_extract
          IO.popen(['7z', 'x','-so', archive_file, file_to_extract, err: :close])
        end

        def list_files archive_file, &block
          IO.popen(['7z', 'l', archive_file, err: :close]) do |stdout|
            [].tap do |data|
              seen_header = false
              intervals = nil
              stdout.each_line do |line|
                line_match = line.match(FILES_HEADER_REGEXP)
                if seen_header
                  next seen_feader = false if line_match
                  parsed_line = read_list_line(line, intervals)
                  next unless valid_extension(parsed_line[:filename])
                  parsed_line[:fileOffset] = data.size
                  data << parsed_line
                  yield parsed_line if block_given?
                elsif line_match
                  if line_match
                    intervals = line_match.to_a.slice(1..-1).map do |str|
                      str.size
                    end
                    seen_header = true
                  end
                else
                  raise line if line.match /Error/
                end
              end
              unless block_given?
                i = 0
                data.sort_by! do |f|
                  f[:filename].scan(/[^\d\.]+|[\d\.]+/).collect { |f| f.match(/\d+(\.\d+)?/) ? f.to_f : f.downcase }
                end
              end
            end
          end
        end

        def valid_extension filename
          extension = File.extname(filename).downcase.gsub(/^\./,'')
          VALID_EXTENSIONS.include?(extension)
        end

        def read_list_line line, ll
          {
            modified: line.slice(0, ll[0]).strip,
            attributes: line.slice(ll[0], ll[1]).strip, # not really used
            filesize: line.slice(ll[0] + ll[1], ll[2]).strip.to_i,
            compressed: line.slice(ll[0] + ll[1] + ll[2], ll[3]).strip.to_i, # not really used, sometimes blank
            filename: line.slice((ll[0] + ll[1] + ll[2] + ll[3] + ll[4])..-1).chomp
          }
        end
      end
    end
  end
end
