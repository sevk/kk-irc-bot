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
  @@last_area_size ||= Time.now.year-1514
  def area
    if @@last_area.size > @@last_area_size
      p '@@last_area.clear '
      @@last_area.clear
    end
    @@last_area[self] ||= IpLocationSeeker.new.seek(self)
  end
  #域名转化为IP
  def host
    domain = self
    return 'IPV6' if domain =~ /^([\da-f]{1,4}(:|::)){1,6}[\da-f]{1,4}$/i
    return self if domain =~ /(\d{1,3}\.){3}\d{1,3}/
    domain = domain.gsub(/\/.*/i,'')
    return domain unless domain.include?('.')
    return Resolv.getaddress(domain) rescue domain
  end
end


if __FILE__ == $0
  if ARGV[0]
    p IpLocationSeeker.new.seek ARGV[0].host
  else
    p IpLocationSeeker.new.seek '8.8.8.8'
  end
end

