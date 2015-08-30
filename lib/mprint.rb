#!/usr/bin/env ruby
# -*- coding: utf-8 -*-
                                                                                 
def printa(* s)
  [s].flatten.map!{|x|
    if win_platform?
      print x.to_s.utf8_to_gb
    else 
      print x.to_s
    end 
  }       
end     
          
def pr *s
  [s].flatten.map!{|x|
    case x
    when String
    if win_platform?
      print x.utf8_to_gb
    else
      print "\t ",x
    end
    else
      if RUBY_VERSION < '1.9'
        case x
        when Array
          print '[' +  x.map{|y| y.inspect}.join(',') + ']'
        else
          print x.inspect
        end
      else
        print x.inspect
      end
    end
  }
  puts
end

def puta(* s)
  [s].flatten.map!{|x|
    if win_platform?
      x = x.to_s.utf8_to_gb rescue x
      print x
    else
      print x.to_s
    end
  }
  puts
end                                       


