#!/usr/bin/env ruby
# -*- coding: utf-8 -*-

#载入plugin

a = Dir.glob 'plugin/*.rb'
a.each { |e|
  next if e =~ /^_/
  begin
    load e
  rescue
    log ''
    puts 'err: plugin: ' + e.to_s.red
    next
  end
  puts 'load plugin: ' + e.to_s.green
}

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

