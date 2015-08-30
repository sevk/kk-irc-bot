#!/usr/bin/env ruby
# -*- coding: utf-8 -*-

#载入plugin

def load_all_plugin
  a = Dir.glob 'plugin/*.rb'
  a.each { |e|
    next if e =~ /^_/
    begin
      load e
    rescue Exception
      log ''
      puts 'err: plugin: ' + e.to_s.red
      next
    end
    puts 'load plugin: ' + e.to_s.green
  }
end

#Thread.new do
  #sleep 30
  #load_all_plugin
#end

# +q
def get_baned
  re = []
  a = Dir.glob '*_baned.ban'
  a.each do |f|
    puts ' baned file : ' + f.to_s
    s = File.read(f)
    p s
    re << s
    File.delete f
  end
  re
end

