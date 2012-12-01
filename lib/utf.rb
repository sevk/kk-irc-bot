#!/usr/bin/env ruby -w
# -*- coding: UTF-8 -*-
#
# ruby utf8 gb2312 gbk gb18030 转换库
require 'rubygems'

if RUBY_VERSION > '1.9'
   Ig = ''
   if RUBY_VERSION > '1.9.2'
      $ec1 = Encoding::Converter.new("UTF-16lE", "UTF-8", :universal_newline => true)
      $ec2 = Encoding::Converter.new("UTF-8","GB2312", :universal_newline => true)
   else
      require 'iconv'
   end
else
   require 'iconv'
   Ig = '//IGNORE'
end

class String
   def gbtoX(code)
      tmp = Encoding::Converter.new("GB18030",code, :universal_newline => true)
      return tmp.convert self if RUBY_VERSION > '1.9.2'
      Iconv.conv("#{@charset}#{Ig}","GB18030#{Ig}",self)
   end
   def code_a2b(a,b)
      tmp = Encoding::Converter.new(a,b, :universal_newline => true)
      return tmp.convert self if RUBY_VERSION > '1.9.2'
      Iconv.conv("#{b}#{Ig}","#{a}#{Ig}",self)
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
end

if $0 == __FILE__
   puts '中文'.togbk
end

