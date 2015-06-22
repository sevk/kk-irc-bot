#!/usr/bin/env ruby
# -*- coding: utf-8 -*-

#自动拜
#hook: pp_join pp_say myexit
#
require 'yaml'
require 'color.rb'
require 'log.rb'

$join_say = {}

def save_baidb
  open('auto_bai.db','w'){|x|
    x.write $join_say.to_yaml
  }
  puts ' save 拜 ok'.red
end

if File.exist?(f='auto_bai.db')
  $join_say=YAML.load_file(f)
elsif File.exist?(f='bai.txt')
  open(f).each_line{|x|
    if x.match(/\s+(\w+)[,:]\s?(拜.+)/i)
      k=$1; v=$2
      $join_say[k]=v
    end
  }
  save_baidb
end

module Ab
  def myexit s
    super s
    save_baidb
  end
  $join_sayskip ||= ['QiongMangHuo']
  def pp_join nick,name,ip,mt,chan
    super nick,name,ip,mt,chan
    if $join_sayskip.include? nick
      return
    end
    if $join_say and a=$join_say[nick]
      return if a.empty?
      msg chan , "#{nick}: #{a}", 60, 10
    end
  end
  def pp_say nick,name,ip,ch,sSay
    super nick,name,ip,ch,sSay
    #p ' pp_say in plugin '
    sSay.force_encoding('utf-8')
    case sSay
    when /\s+(\w+)[,:]\s*(拜.+)/i
      k=$1; v=$2.strip.gsub!(/[\x00-\x10]/,'')
      p v
      p v.encoding
      if not $join_say.include? nick
        return
      end
      case v.force_encoding('utf-8')
      when /拜clear|拜-/i
        msg ch , " ok clear ." , 0, 10
        $join_say.delete k
        return
      end
      $join_say[k]=v
      #p "add js : #{v} (count: #{$join_say.size}) "
      msg ch , "ok { #{k} => #{v} }" , 20, 10
      save_baidb
    end
  end
rescue Exception
  log ''
end

if RUBY_VERSION > '2.0'
  IRC.prepend Ab
  puts ' hook pp_join ok'
else
  puts "本插件需要ruby2.0以上".red
end


