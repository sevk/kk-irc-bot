#!/usr/bin/env ruby
# -*- coding: utf-8 -*-

#自动拜
#hook: pp_join pp_say myexit
#
require 'yaml'
require 'color.rb'
require 'log.rb'
require 'time'
require 'kk-zlib.rb'

$join_say ||= {}
$data['ab'] ||= {}
$data['ab'].default = 0

def save_baidb
  return if $join_say.size < 1
  open('auto_bai.dbx','wb'){|x|
    x.write $join_say.to_yaml.deflate
  }
  open('auto_bai.db','wb'){|x| x.write $join_say.to_yaml } if rand < 0.1
  puts ' save 拜 ok'.red
end

if File.exist?(f='auto_bai.dbx')
  $join_say=YAML.load( open(f,'rb').read.inflate )
elsif File.exist?(f='auto_bai.db')
  $join_say=YAML.load( open(f,'rb').read )
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
  $join_sayskip = ['QiongMangHuo','happyaron','cherrot']
  def pp_join nick,name,ip,mt,chan
    super nick,name,ip,mt,chan
    if $join_sayskip.include? nick
      return
    end
    if $join_say and a=$join_say[nick]
      return if a.empty?
      return if Time.at($data['ab'][nick]) > Time.parse(Time.now.strftime("%Y-%m-%d 00:00:00"))
      msg chan , "#{nick}: #{a}", 60, 10
      $data['ab'][nick] = Time.now.to_i
    end
  rescue Exception
    log ''
  end

  def pp_say nick,name,ip,ch,sSay
    super nick,name,ip,ch,sSay
    sSay.force_encoding('utf-8')
    re = /\s*([\-\|\\\/\w]+)[,:\s]+(拜.+)/i
    #p sSay =~ re
    #p $1,$2
    case sSay
    when re
      k=$1; v=$2.strip.gsub(/[\x00-\x10]/,'')
      if v.match(/[,.，。!].../) #不能有标点
        pr " skip for ,.! "
        return
      end
      #pr "v:",v , v.encoding
      if not $join_say.include? nick
        pr " not include #{nick}"
        return
      end
      case v.force_encoding('utf-8')
      when /拜(-|'')/i
        msg ch , " ok 白名单 #{k} :) " , 5 , 10
        $join_say[k] = ''
        save_baidb
        return
      when /拜(clear|del)/i
        msg ch , " ok del ." , 0, 10
        $join_say.delete k
        save_baidb
        return
      end
      return if k == nick #自己不能修改自己的?
      return if $join_say[k]== '' #是 '' 就是白名单
      if $join_sayskip.include? k
        return
      end
      sSay.chop! while sSay.bytesize > 50 #限制长度
      if $join_say[k]==v
        return
      end
      $join_say[k]=v
      p "add js : #{k}=>#{v} (count: #{$join_say.size}) "
      msg ch , "#{nick}: ok #{k} => #{v} " , 20, 10
      save_baidb
    end
  rescue Exception
    log ''
  end
end

if RUBY_VERSION > '2.0'
  IRC.prepend Ab
  puts ' hook pp_join ok'
else
  puts "本插件需要ruby2.0以上".red
end


