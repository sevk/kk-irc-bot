#!/usr/bin/env ruby
# coding: utf-8
#
#
require 'rubygems'
require 'bundler/setup'
require 'qqwry'

f='QQWry.Dat'
unless File.exist? f
  p f + ' not found '
end

class IpLocationSeeker
  def seek(ip) #查询IP
    unless File.exist? 'QQWry.Dat'
      return ''
    end

    db = QQWry::Database.new('QQWry.Dat')
    r = db.query(ip)
    "#{r.country} #{r.area}"
  end
end

p IpLocationSeeker.new.seek('8.8.8.8') if __FILE__ == $0
p IpLocationSeeker.new.seek ARGV[0] if __FILE__ == $0

