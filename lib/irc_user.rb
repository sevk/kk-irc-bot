#!/usr/bin/env ruby
# -*- coding: utf-8 -*-
# sevkme@gmail.com

#刷屏检测阀值,可以微调.
$maxfloodme ||= 87.0 #70
$maxflood ||= 33.3  #35.0
$initFlood = 83.0 #83
$maxNamed = 4*(Time.now.year-2000) + 200

class All_user
  attr_accessor :RP, :addr , :index

  def initialize
    @pos_write = 0
    @index=Hash.new # name => pos
    @name=Array.new # index => name
    @ip=Array.new
    @addr=Hash.new
    #@count_said=Array.new
    @sex=Array.new

    #[1]=>重复次数,[2]=>人品值
    #@RP=Array.new(3,[]) #why wrong , very surprised
    init_pp
    puts 'users class start' if $debug
  end
  def init_pp
		@RP=Array.new(3) {[]}
    $mode=Array.new
    $ban_time=Array.new
    $time_in=Array.new
    $timelastsay=Array.new
    $timelastsayme=Array.new
    $timelast6say=Array.new
    $timelast6me=Array.new
    $tWarned=Array.new
    $lastsay=Array.new
  end

  def havenick?(nick)
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

  #解析网页登录的IP
  def ip_from_webname(name)
    name.scan(/../).map{|x| x.hex}.join('.')
  end

  #get 人品
  def getrp(nick)
    index = getindex(nick)
    return 0 unless index
    @RP[2][index]=0 if not @RP[2][index]
    return @RP[2][index]
  end

  #记录nick库
  def add(nick,name,ip)
    nick.strip!
    name.gsub!(/[in]=|~|^\+|^\@/i,'') #删除nick 开头的@ + V
    print "name:"; p name
    ip=ip_from_webname(name) if ip =~ /^gateway\/web\/freenode/i
    index = getindex(nick)
    p "index: #{index} "
    if index
      if ip != @ip[index]
        chg_ip(nick,ip)
      end
      return false
    end
    puts " add nick: #{nick} "
    oldname = @index.key(@pos_write)
    #删除原位置
    @index.delete oldname
    @addr.delete oldname

    @addr[nick]= getaddr_fromip(ip)

    @index[nick] = @pos_write
    @name[@pos_write]= name
    @ip[@pos_write]= ip
    #@count_said[@pos_write] = @count_said[@pos_write].to_i + 1
    #puts @addr[nick]
    t = Time.now
    $time_in[@pos_write]= t
    $timelastsay[@pos_write]= t
    $timelastsayme[@pos_write]= t - 11
    $timelast6me[@pos_write]= $initFlood * 1.2
    $timelast6say[@pos_write]= $initFlood * 1.2
    $tWarned[@pos_write]= t - 3600#加入黑名单1个小时
    $lastsay[@pos_write]=nil
    #$ban_time=read_from_db
    $ban_time[@pos_write]=Time.now - 7200
    setmode(@pos_write,'')
    @RP[1][@pos_write] = 0
    setrp(@pos_write,ip)

    if @pos_write >= $maxNamed
      @pos_write = 0
      puts t.to_s.blueb
      puts @index.size
    else
      @pos_write += 1
    end
    @pos_write
  end

  def isBlocked?(nick)
    index = getindex(nick)
    return unless index
    $timelastsayme[index] = Time.now - 20 if ! $timelastsayme[index]
    return Time.now - $timelastsayme[index] < 5 #10秒之内就Block
  end

  def sayorder()
  end

  def set_ban_time(nick)
    $ban_time[getindex(nick)] = Time.now
  end
  def get_ban_time(nick)
    $ban_time[getindex(nick)] ||= Time.now - 3600
  end
  def setLastSay(nick,w)
    i=getindex(nick)
    i ||= add(nick)
    if w == $lastsay[i]
      @RP[1][i] +=1
    else
      @RP[1][i] =0
      $lastsay[i] =w
    end
  end

  def has_said?(s)
    return false if s.size < 4
    #true == $lastsay.compact.select{|x| break true if x =~ /#{s}/ }
  end

  #rep?
  def rep(nick)
    i=getindex(nick)
    if @RP[1][i] > 2
      #print nick , ' 重复 rep . ' , @RP[1][i] , getLastSay(nick), 10.chr
      @RP[1][i]=0
      return true
    end
  end

  def getLastSay(nick)
    $lastsay[getindex(nick)]
  end
  
  def floodreset(nick)
    index = getindex(nick)
    return unless index
    $timelast6say[index] = $initFlood
  end
  def floodmereset(nick)
    index = getindex(nick)
    return unless index
    $timelast6me[index] = $initFlood
  end
  def check_flood_me(nick)#更严格
    index = getindex(nick)
    return unless index
    $timelast6me[index] = $initFlood * 2 if ! $timelast6me[index]
    p "~me #{$timelast6me[index]}" if $timelast6me[index] < $maxflood+10
    return $timelast6me[index] < $maxfloodme
  end

  def check_flood(nick)
    index = getindex(nick)
    return unless index
    if ! $timelast6say[index]
      $timelast6say[index] = $initFlood 
    elsif $timelast6say[index] < 0
      $timelast6say[index] = $initFlood 
    end
    p "~ #{$timelast6say[index]}" if $timelast6say[index] < $maxflood + 6
    return $timelast6say[index] < $maxflood
  end

  def said_me(nick,name,ip,fix=0.0)
    if ! @index
      return add(nick,name,ip)
    end
    if @index.include?(nick)
      index = getindex(nick)
    else
      return add(nick,name,ip)
    end
    t = Time.now
    $timelastsayme[index] = t if ! $timelastsayme[index]
    $timelast6me[index] = $initFlood if ! $timelast6me[index]
    $timelast6me[index] = $initFlood if $timelast6me[index] > $initFlood or $timelast6me[index] < 1
    $timelast6me[index] = $timelast6me[index] / 5 * 4 + 
      (t-$timelastsayme[index]) + fix + getrp(nick)/12.0
    #p "~me #{nick} #{$timelast6me[index]}"
    $timelastsayme[index] = t
  end
  
  def said(nick,name,ip,fix=0.0)
    if not @index
      puts '#无任何用户'
      return add(nick,name,ip)
    end
    if @index.include?(nick)
      index = getindex(nick)
    else
      puts '#无此用户'
      return add(nick,name,ip)
    end
    #~ puts '21 $timelast6say[index]:  index: ' + index.to_s
    t = Time.now
    $timelastsay[index] = t if ! $timelastsay[index]
    $timelast6say[index] = $initFlood if ! $timelast6say[index]
    $timelast6say[index] = $initFlood if $timelast6say[index] > $initFlood or $timelast6say[index] < 1
    $timelast6say[index] = $timelast6say[index] / 5 * 4 + 
      (t - $timelastsay[index]) + fix + getrp(nick)/11.0
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

  #用于flood检测等功能，可以有 10%的正加成
  def setrp(index,ip)
    if ip.match(/\w+\/\w+|unaffiliated/)
      p 'RP=30'
      @RP[2][index] = 40
    else
      @RP[2][index] = 0
    end
  end

  def chg_ip(nick,ip)
    index = getindex(nick)
    if index == nil #未记录的用户名
      return 1
    end

    @ip[index]=ip

    @addr[nick]= getaddr_fromip(ip)
    setrp(index,ip)
  end

  def chg_nick(old,new)
    index = getindex(old)
    if index == nil #未记录的用户名
      return 1
    end
    @index[new]=index
    @index.delete(old)
    @addr[new]=@addr[old]
    @addr.delete(old)
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
  def all_nick
    @index.keys.map{|x| x.delete '@'}
  end

  def completename(s)
    return s if !s or s=='' or @index.include?(s)
    #return @index.select{|x,y| x =~ /#{Regexp::escape s}/i}.keys[0]
    all_nick.grep(/#{s}/i)[0]
  end

  def ipgrep(ip)
  end

  def addrgrep(s)
    tmp = @addr.select{|x,y| y =~ /#{s.strip}/i}.to_a.map{|x,y| x}.sort
    return "#{tmp.count}位 #{tmp.join(' ')}"
  end
  def setip(nick,name,ip)
    index = getindex(nick)
    return add(nick,name,ip) unless index
    @ip[index]=ip
    @addr[nick]=getaddr_fromip(ip)
  end

  def setmode(index,mode='')
    $mode[index]=mode
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
    "人品值：#{getrp nick}"
  end
end

