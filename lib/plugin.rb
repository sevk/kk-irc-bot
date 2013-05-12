#!/usr/bin/env ruby
# -*- coding: utf-8 -*-

require 'find'
include Find

#载入plugin

if File.directory? 'plugin'
  Find.find(Dir.pwd + '/plugin/') do |e|
    if File.extname(e) == '.rb'
      puts 'load plugin: ' + e.to_s.red
      load e
    end
  end
end

# +q
def get_baned
  re = []
  Find.find('.') do |f|
    if f =~ /_baned\.ban/
      puts ' baned file : ' + f.to_s
      s = File.read(f)
      p s
      re << s
      File.delete f
    end
  end
  re
end

