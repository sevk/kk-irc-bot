#!/usr/bin/env ruby
# -*- coding: utf-8 -*-
# 取笑话

$: << '..'
$: << '../lib/'
$:.uniq!
require 'mechanize'
require 'htmlentities'
require 'utf.rb'
def joke(n=nil)
  n ||= rand(39986)
  url="http://xiaohua.zol.com.cn/detail1/#{n}.html"
  puts url
  a=Mechanize.new
  s = a.get url
  begin
    ti = s.at('.article-title').text
    text = s.at('.article-text').text
  rescue
    log ''
    return joke
  end
  s= " #{ti} : #{text}"
  s=s.code_a2b(guess(s) ,'utf-8').unescapeHTML
  s.force_encoding 'utf-8'

  #中文 => 英文
  {'：' => ':' , '，' => "," ,  /”|“/ => '"' , /[‘’]/ => "'" ,
    /\s+|\t/ => ' ' , '？' => '?'
  } .each { |x,y| 
    s.gsub!(x,y)
  }

  puts s
  $fun ||= 800
  if s.bytesize > $fun
    sleep 0.05
    s=joke
  end
  s.prepend 'xiaohua.zol.com.cn ' if rand < 0.1
  "笑话标题:#{s}"
end
alias 给大爷讲个笑话 joke

if __FILE__ == $0
  puts joke
end

