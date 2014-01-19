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
  if text.gsub(/\s+/,'').empty?
    text = s.image_with(:src => /xiaohua\./).src
    text.prepend "竟然是图片"
    #sleep 0.1
    #p text
    #return joke
  end
  s= " 笑话标题:#{ti} :#{text}"
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
  s.prepend url if rand < 0.2
  s
end
alias 给大爷讲个笑话 joke

if __FILE__ == $0
  puts joke
end

