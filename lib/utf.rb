#!/usr/bin/env ruby
# -*- coding: UTF-8 -*-
#
# ruby utf8 gb2312 gbk gb18030 转换库
require 'rubygems'

if defined? Encoding::Converter
  $ec1 = Encoding::Converter.new("GBK", "UTF-8", :universal_newline => true)
  $ec2 = Encoding::Converter.new("UTF-8","GB2312", :universal_newline => true)
  $ec3 = Encoding::Converter.new("UTF-16lE", "UTF-8", :universal_newline => true)
else
  require 'iconv'
end

class String
   def code_a2b(a,b)
     return self if a =~ /#{b}/i
      if RUBY_VERSION > '1.9' and defined? Encoding::Converter
        tmp = Encoding::Converter.new(a,b, :universal_newline => true)
        tmp.convert self rescue self
      else
        Iconv.conv("#{b}//IGNORE","#{a}//IGNORE",self)
      end
   end
   def gbtoX(code)
     code_a2b('GB18030',code)
     #code_a2b('CP20936',code)
     #code_a2b('GB2312',code)
   end

   def togb2312
      return $ec2.convert self if RUBY_VERSION > '1.9.2'
      Iconv.conv("CP20936#{Ig}","UTF-8#{Ig}",self)
   end
   def togbk
      if RUBY_VERSION > '1.9.2'
         $ec2.convert self rescue self
      else
         Iconv.conv("GBK#{Ig}","UTF-8#{Ig}",self)
      end
   end
   def togb
      if RUBY_VERSION > '1.9.2'
         $ec2.convert self rescue self
      else
         Iconv.conv("GB2312#{Ig}","UTF-8#{Ig}",self)
      end
   end
   alias to_gb togb

   def utf8_to_gb
      return $ec2.convert self if RUBY_VERSION > '1.9.2'
      Iconv.conv("GB18030#{Ig}","UTF-8#{Ig}",self)
   end
   def gb_to_utf8
      return $ec1.convert self if RUBY_VERSION > '1.9.2'
      Iconv.conv("UTF-8#{Ig}","GB18030#{Ig}",self)
   end
   def to_utf8
      return $ec1.convert self if RUBY_VERSION > '1.9.2'
      Iconv.conv("UTF-8#{Ig}","GB18030#{Ig}",self)
   end
   alias toutf8 to_utf8

   def to_hex(s=' ')
      self.each_byte.map{|b| "%02X" % b}.join(s)
   end
end

begin
  require 'rchardet19'
rescue LoadError
  s="载入库错误,命令: 请看README"
  s = s.utf8_to_gb if Gem.win_platform?
  puts s
  puts $!.message + $@[0]
end
def guess(s)
  CharDet.detect(s)['encoding'].upcase
end

#字符串编码集猜测
def guess_charset(str)
  return if str.empty?
   s=str.gsub(/[\x0-\x7f]/,'') rescue str.clone
  return if s.bytesize < 6
  while s.bytesize < 25
    s << s
  end
  return guess(s) rescue nil
end

if $0 == __FILE__
   puts '中文'.togbk
end
