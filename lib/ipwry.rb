#!/usr/bin/env ruby
# -*- coding: utf-8 -*-
#

require 'rubygems'
#require 'bundler/setup'
require 'qqwry'

$fqqwry='qqwry.dat'
unless File.exist? $fqqwry
  d = File.dirname __FILE__
  $fqqwry = File.join d, $fqqwry
  unless File.exist? $fqqwry
    p $fqqwry + ' not found '
  end
end

class IpLocationSeeker
  def seek(ip) #查询IP
    unless File.exist? $fqqwry
      return ''
    end

    db = QQWry::Database.new $fqqwry
    r = db.query(ip)
    "#{r.country} #{r.area}"
  end
end

class String
  @@last_area ||={}
  @@last_area_size ||= $maxNamed 
  @@last_area_size ||= Time.now.year/2
  def area
    @@last_area.clear if @@last_area.size > @@last_area_size
    unless @@last_area.has_key? self
      @@last_area[self]= IpLocationSeeker.new.seek self
    end
    @@last_area[self]
  end
end


if __FILE__ == $0
  if ARGV[0]
    p IpLocationSeeker.new.seek ARGV[0]
  else
    p IpLocationSeeker.new.seek '8.8.8.8'
  end
end

