module ComixZap
    class ZipReader
        attr_accessor :file

        COMPRESSION_UNCOMPRESSED = 0
        COMPRESSION_DEFLATE      = 8

        def initialize filename
            @filename = filename
            @file = File.open filename
        end

        def check_file
            @file.seek(0)
            header = @file.read(4)
            raise 'File is not a zip file' if header != "PK\3\4"
        end

        def entries
            eocd = self.eocd
            @file.seek(eocd[:cd_offset])
            (1..eocd[:cd_count]).map do
                self.cd_entry
            end
        end

        def cd_entry
            header = @file.read(4)
            raise 'Central Directory not found' if header != "PK\1\2"
            entry_bin = @file.read(42)
            entry_values = entry_bin.unpack('S<S<S<S<S<S<L<L<L<S<S<S<S<S<L<L<')

            filename = @file.read(entry_values[9])
            extraField = @file.read(entry_values[10])
            comment = @file.read(entry_values[11])

            #camel case to maintain compatibility
            {
                version: entry_values[0],
                versionNeeded: entry_values[1],
                flags: entry_values[2],
                compressionType: entry_values[3],
                mtime: entry_values[4],
                mdate: entry_values[5],
                crc32: entry_values[6],
                csize: entry_values[7],
                usize: entry_values[8],
                filenameLength: entry_values[9],
                extraFieldLength: entry_values[10],
                commentLength: entry_values[11],
                diskStart: entry_values[12],
                internalAttr: entry_values[13],
                externalAttr: entry_values[14],
                fileOffset: entry_values[15]
            }.merge({
                filename: filename,
                comment: comment
            })
        end

        def file_info_at_offset offset
            @file.seek offset
            header = @file.read(4)
            raise 'File header not found at offset' if header != "PK\3\4"
            entry_bin = @file.read(26)
            entry_values = entry_bin.unpack('S<S<S<S<S<L<L<L<S<S<')

            filename = @file.read(entry_values[8])
            extraField = @file.read(entry_values[9])

            {
                versionNeeded: entry_values[0],
                flags: entry_values[1],
                compressionType: entry_values[2],
                mtime: entry_values[3],
                mdate: entry_values[4],
                crc32: entry_values[5],
                csize: entry_values[6],
                usize: entry_values[7],
                filenameLength: entry_values[8],
                extraFieldLength: entry_values[9],
                rawOffset: offset + 4 + entry_bin.size + filename.size + extraField.size
            }.merge({
                filename: filename
            })
        end

        def eocd
            #first, skip to the end, find the EOCD header 
            @file.seek(-22, IO::SEEK_END)
            header = @file.read(4)
            raise 'End of Central Directory not found' if header != "PK\5\6"
            entry_bin = @file.read(16)
            entry_values = entry_bin.unpack('S<S<S<S<L<L<')

            {
                disk_number: entry_values[0],
                cd_disk_number: entry_values[1],
                cd_count: entry_values[2],
                cd_disk_count: entry_values[3],
                cd_size: entry_values[4],
                cd_offset: entry_values[5]
            }
        end

        def close
            @file.close
        end

        def self.gzip_header file_info
            [0x1f8b,8,0,0,0,0].pack('nCCCCV')
        end

        def self.gzip_footer file_info
            [file_info[:crc32], file_info[:usize]].pack('VV')
        end
    end
end
