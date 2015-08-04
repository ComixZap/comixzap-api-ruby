module ComixZap
  module Reader
    autoload :SevenZip, 'comixzap/reader/seven_zip'
    class << self
      REGEX_DOTFILE = /^\./
      REGEX_COMICFILE = /\.cb(z|r)$/i

      def directory path, &block
        data = []
        Dir.entries(path).each do |filename|
          next if filename =~ REGEX_DOTFILE
          full_path = File.join(path, filename)
          is_directory = File.directory?(full_path)
          next unless is_directory || (filename =~ REGEX_COMICFILE)
          file_data = {
            filename: filename,
            size: File.size(full_path),
            directory: is_directory
          }
          yield file_data if block_given?
          data << file_data
        end
        unless block_given?
          data.sort_by do |entry|
            [entry[:directory] ? 0 : 1] + Util.natural_sort_array(entry[:filename])
          end
        end
      end

      def list_archive_files path, &block
        SevenZip::list_files path, &block
      end

      def file_at_offset path, offset
        files = SevenZip::list_files path
        files[offset][:filename]
      end

      def extract_file_at_offset path, offset
        filename = file_at_offset path, offset
        extract_file path, filename
      end

      def extract_file path, filename
        SevenZip::extract_file path, filename
      end
    end
  end
end
