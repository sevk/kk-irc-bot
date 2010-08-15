#!/usr/bin/env ruby
# coding: utf-8
# 版本需ruby较新的版本, 比如ruby1.8.7以上 或 ruby1.9.1 以上

def os_family
  case RUBY_PLATFORM
  when /ix/i, /ux/i, /gnu/i,
    /sysv/i, /solaris/i,
    /sunos/i, /bsd/i
    "unix"
  when /win/i, /ming/i
    "windows"
  else
    "other"
  end
end
