#!/usr/bin/env ruby
# -*- coding: utf-8 -*-
# 取笑话

$: << '..'
$: << '../lib/'
$:.uniq!
require 'mechanize'
require 'htmlentities'
require 'utf.rb'

module Allowa
  def joke(n=nil)
    sleep $msg_delay / 3.0
    n ||= rand(39986)
    url="http://xiaohua.zol.com.cn/detail1/#{n}.html"
    puts url
    a=Mechanize.new
    s = a.get url
    begin
      ti = s.at('.article-title').text
      text = s.at('.article-text').text
      if text.gsub(/\s+/,'').empty?
        img = s.image_with(:src => /xiaohua\./).src
        s= " #{img} #{ti}"
        if rand < 0.3
          s.prepend "竟然是图片"
        else
          return joke
        end
      else
        s= " #{ti} :#{text}"
        s.prepend url if rand < 0.16
      end
    rescue
      log ''
      return joke
    end
    s=s.code_a2b(guess(s) ,'utf-8').unescapeHTML
    s.force_encoding 'utf-8'

    #中文 => 英文
    {/：|∶/ => ':' , '，' => "," ,  /”|“/ => '"' , /[‘’]/ => "'" ,
      /\s+|\t/ => ' ' , '？' => '?'
    } .each { |x,y| 
      s.gsub!(x,y)
    }

    $fun ||= 800
    if s.bytesize > $fun
      puts " joke size > $fun "
      sleep 0.05
      s=joke
    end
    s
  end
end
include Allowa

if __FILE__ == $0
  puts joke
end

