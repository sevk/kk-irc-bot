#!/usr/bin/env ruby
# coding: utf-8

Thread.new do
  sleep 3
  require 'dic.rb' unless defined? getGoogle
  puts '延时加载某些函数.'
  def method_missing(m, *args, &block)
    sleep 0.0001
    case s= m.to_s
    when /^to_/
      return super
    end
    print "方法未找到: "
    p m
    #p args
    #p block
    p caller
    getGoogle(s)
  end  
end

