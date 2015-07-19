require 'rubygems'
require 'zlib'

class String
  def inflate #unzip
    zstream = Zlib::Inflate.new
    buf = zstream.inflate(self)
    zstream.finish
    zstream.close
    buf
  end
  def deflate #zip
    zstream = Zlib::Deflate.new
    buf = zstream.deflate(self,Zlib::FINISH)
    zstream.close
    buf
  end
end
