require 'tmpdir'

module Updater
  class Util
    class << self 
      def tempio
        fp = begin
          File.open("#{Dir::tmpdir}/#{rand}",
                    File::RDWR|File::CREAT|File::EXCL, 0600)
        rescue Errno::EEXIST
          retry
        end
        File.unlink(fp.path)
        fp.binmode
        fp.sync = true
        fp
      end
    
    
    end
  end
end