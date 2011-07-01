require 'find'
#载入plugin

if File.directory? 'plugin'
  Find.find(Dir.pwd + '/plugin/') do |e|
    if File.extname(e) == '.rb'
      puts 'load plugin: ' + e.to_s.red
      load e
    end
  end
end
