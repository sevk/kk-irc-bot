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
  n ||= rand(17786)
  url="http://xiaohua.zol.com.cn/detail1/#{n}.html"
  puts url
  a=Mechanize.new
  s = a.get url
  ti = s.at('.article-title').text
  text = s.at('.article-text').text
  s= "#{ti} : #{text} "
  s=s.code_a2b(guess(s) ,'utf-8').unescapeHTML
  $fun ||= 800
  if s.bytesize > $fun
    sleep 0.1
    s=joke
  end
  s.gsub!(/\s+|\t/,' ')
  s
end
alias 给大爷讲个笑话 joke

if __FILE__ == $0
  puts joke
end

