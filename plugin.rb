require 'find'
#载入plugin
Find.find(File.expand_path(File.dirname(__FILE__))+'/plugin/') do |e|
  if File.extname(e) == '.rb'
    puts e.to_s.red
    load e
  end
end
