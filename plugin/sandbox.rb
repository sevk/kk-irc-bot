
require "shikashi"
include Shikashi

def sandbox_init
  return if @priv
  @s=Sandbox.new
  @priv = Privileges.new
  [:p ,:print ,:puts].each {|x|
    @priv.allow_method x }

  a = [Math,Fixnum,Bignum,String,Array,Hash,Time,Enumerator,NilClass,Float,Random,Regexp,Complex,TrueClass,FalseClass,SecureRandom,YAML,JSON,Allowa]
  a.flatten.inject([]){ |x,y|
    x | y.methods | y.instance_methods
  } .each{|x|
    next if x =~ /eval/
    @priv.allow_method x
  }

  a.inject([]){|x,y| x | [y] | y.constants} .each{|x|
    next if x =~ /eval/
    @priv.allow_const_read x
  }
end

def get_sandbox str
  sandbox_init
  return @s.run(@priv, str ) rescue $!.message
end

