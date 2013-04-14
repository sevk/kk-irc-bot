#!/usr/bin/env ruby
# coding: utf-8
#
#
require 'rubygems'
require 'bundler/setup'
require 'qqwry'
#require 'utf.rb'

class IpLocationSeeker
  def seek(ip) #查询IP
    f='QQWry.Dat'
    unless File.exist? f
      p f + ' not found '
      return ''
    end

    db = QQWry::Database.new('QQWry.Dat')
    r = db.query(ip)
    #p r
    "#{r.country} #{r.area}"
  end
end

p IpLocationSeeker.new.seek('8.8.8.8') if __FILE__ == $0

