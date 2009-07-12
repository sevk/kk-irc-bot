#!/usr/bin/env ruby1.9
# coding: utf-8
#51070540@qq.com ; sevkme@gmail.com

Maxfloodme = 83 #75
Maxflood = 37   #39
Initflood = 83 #83
Maxnamed = 150

class ALL_USER
  #attr :nick, true
  def initialize
    @pos_write = 0
    @index=Hash.new
    $lastsay=Array.new
    @name=Array.new
    @ip=Array.new
    @addr=Hash.new
    $time_in=Array.new
    $timelastsay=Array.new
    $timelastsayme=Array.new
    $timelast6say=Array.new
    $timelast6me=Array.new
    $tWarned=Array.new
    $lastsay=Array.new

    puts 'users class start' if $debug
  end
  def addr
    return @addr
  end
  def havenick(nick)
    @index.include?(nick)
  end
  def getindex(nick)
    if @index.include?(nick)
      return @index[nick]
    else
      #puts 'getindex 未找到nick: ' + nick
      return nil
    end
  end
  def add(nick,name,ip)
    name.gsub!(/[in]=/i,'')
    if name =~ /^U\d{5}$/ && ip == '59.36.101.19'
      #不记录黑名单用户
      return 19
    end
    #puts '6 add ' +  nick if $debug
    return if nick == nil
    if @index.include?(nick)
      #~ puts nick + '已经存在'
      return false
    end
    @index.delete(@index.key(@pos_write))#删除原位置
    @index[nick] = @pos_write
    @name[@pos_write]= name
    @ip[@pos_write]= ip
    @addr[nick]= getaddr_fromip(ip)
    #puts @addr[nick]
    t = Time.now
    $time_in[@pos_write]= t
    $timelastsay[@pos_write]= t
    $timelastsayme[@pos_write]= t
    $timelast6me[@pos_write]= Initflood * 2
    $timelast6say[@pos_write]= Initflood * 2
    $tWarned[@pos_write]= t - 3600#加入黑名单1个小时
    $lastsay[@pos_write]=''

    if @pos_write == Maxnamed
      @pos_write = 0
      p @index.size
      p t
    else
      @pos_write += 1
    end
    return nil
  end
  def isBlocked?(nick)
    index = getindex(nick)
    return false if index == nil
    $timelastsayme[index] += 1
    return Time.now - $timelastsayme[index] < 10 #10秒之内就Block
  end
  def sayorder()
     
  end

  def lastSay=(nick,w)
    $lastsay[getindex(nick)]=w
  end
  def setLastSay(nick,w)
    $lastsay[getindex(nick)]=w
  end
  def sGetLastSay(nick)
    $lastsay[getindex(nick)]
  end
  
  def floodreset(nick)
    index = getindex(nick)
    return if index == nil
    $timelast6say[index] = Initflood
  end
  def floodmereset(nick)
    index = getindex(nick)
    return if index == nil
    $timelast6me[index] = Initflood
  end
  def check_flood_me(nick)#更严格
    index = getindex(nick)
    return false if index ==nil
    p "~me #{nick} #{$timelast6me[index]}" if $debug
    return $timelast6me[index] < Maxfloodme
  end
  def check_flood(nick)
    index = getindex(nick)
    return false if index ==nil
    p "~ #{nick} #{$timelast6say[index]}" if $debug
    return $timelast6say[index] < Maxflood
  end

  def said_me(nick,name,ip)
    if @index == nil
      return add(nick,name,ip)
    end
    if @index.include?(nick)
      index = getindex(nick)
    else
      return add(nick,name,ip)
    end
    t = Time.now
    $timelast6me[index] = ($timelast6me[index] /6 ) * 5 +  (t - $timelastsayme[index])
    $timelast6me[index] = Initflood if $timelast6me[index] > Initflood * 2
    $timelastsayme[index] = t
  end
  
  def said(nick,name,ip)
    if @index == nil
      #~ puts '#无任何用户'
      return add(nick,name,ip)
    end
    if @index.include?(nick)
      index = getindex(nick)
    else
      #puts '#无此用户'
      return add(nick,name,ip)
    end
    #~ puts '21 $timelast6say[index]:  index: ' + index.to_s
    t = Time.now
    $timelast6say[index] = ($timelast6say[index] /6 ) * 5 +  (t - $timelastsay[index])
    $timelast6say[index] = Initflood if $timelast6say[index] > Initflood + 90
    $timelastsay[index] = t
  end

  def saidAndCheckFlood(nick,name,ip,w)
    said(nick,name,ip)
    setLastSay(nick,w)
    return check_flood(nick)
  end
  def saidAndCheckFloodMe(nick,name,ip)
    said_me(nick,name,ip)
    return check_flood_me(nick)
  end
  def chg_ip(nick,ip)
    index = getindex(nick)
    if index == nil #未记录的用户名
      return 1
    end
    @ip[index]=ip
    @addr[nick]=getaddr_fromip(ip)
  end

  def chg_nick(old,new)
    index = getindex(old)
    if index == nil #未记录的用户名
      return 1
    end
    @index[new]=index
    @index.delete(old)
  end
  def del(nick,ip)
    return #if ip != '59.36.101.19'
    #return floodreset(nick)
    #index = getindex(nick)
    #@index.delete(nick)
  end
  def getname(nick)
    return @name[getindex(nick)]
  end
  def all_nick()
    @index.keys
  end
  def completename(s)
    return s if !s or s=='' or getindex(s)
    tmp='somebody'
    @index.each_key { |x| (tmp= x;break)if x.to_s =~ /#{Regexp::escape s}/i }
    p '----------completename----'
    return tmp
  end
  def addrgrep(s)
    @addr.select{|x,y| y =~ /#{s}/}.to_a.join(' ').gsub(/\s(\d)/i){":#{$1}"}
  end
  def setip(nick,name,ip)
    index = getindex(nick)
    return add(nick,name,ip) unless index
    @ip[index]=ip
    @addr[nick]=getaddr_fromip(ip)
  end
  def getip(nick)#记忆的IP
    index = getindex(nick)
    return unless index
    return @ip[index].to_s
  end
  def getaddr(nick)#记忆的IP
    return @addr[nick].to_s
  end
  def ims(nick)
    index = getindex(nick)
    return $timelast6say[index]
  end
  def igetlastsay(nick)
    p '60 getlastsay nick: ' , nick
    index = getindex(nick)
    return $timelast6say[index]
  end
end

