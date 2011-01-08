#!/usr/bin/env ruby
# coding: utf-8

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
