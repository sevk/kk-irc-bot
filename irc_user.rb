#!/usr/bin/ruby -w
#51070540@qq.com ; sevkme@gmail.com

Maxfloodme = 77 #75
Maxflood = 37   #40
Initflood = 88 #83
Maxnamed = 130
class ALL_USER
  #attr :nick, true
  def initialize
    @pos_write = 0
    @index=Hash.new
    @lastsay=Array.new
    @name=Array.new
    @addr=Array.new
    @time_in=Array.new
    @timelastsay=Array.new
    @timelastsayme=Array.new
    @timelast6say=Array.new
    @timelast6me=Array.new
    @tWarned=Array.new
    $lastsay=Array.new

    puts 'users class start'
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
    name.gsub!(/n=/i,'')
    if name =~ /^U\d{5}$/ && ip == '59.36.101.19'
      #不记录U用户
      return 19
    end
    #~ puts '6 add ' +  nick
    return if nick == nil
    if @index.include?(nick)
      #~ puts nick + '已经存在'
      return false
    end
    @index.delete(@index.index(@pos_write))#删除原位置
    @index[nick] =@pos_write
    @name[@pos_write]= name
    @addr[@pos_write]= ip
    t = Time.now
    @time_in[@pos_write]= t
    @timelastsay[@pos_write]= t
    @timelastsayme[@pos_write]= t
    @timelast6me[@pos_write]= Initflood
    @timelast6say[@pos_write]= Initflood
    @tWarned[@pos_write]= t - 3600#加入黑名单1个小时
    $lastsay[@pos_write]=''

    if @pos_write == Maxnamed
      @pos_write =0
      p t
    else
      @pos_write +=1
    end
    return nil
  end
  def isBlocked?(nick)
    index = getindex(nick)
    return false if index == nil
    @timelastsayme[index] += 1
    return Time.now - @timelastsayme[index] < 10 #10秒之内就Block
  end
  def sayorder()
     
  end
  def setLastSay=(nick,w)
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
    @timelast6say[index]=  Initflood
  end
  def floodmereset(nick)
    index = getindex(nick)
    return if index == nil
    @timelast6me[index]=  Initflood
  end
  def check_flood_me(nick)#更严格
    index = getindex(nick)
    return false if index ==nil
    #~ p '5 ' + nick + @timelast6me[index].to_s
    return @timelast6me[index] < Maxfloodme
  end
  def check_flood(nick)
    index = getindex(nick)
    return false if index ==nil
    #~ p '4 ' + @timelast6say[index].to_s
    return @timelast6say[index] < Maxflood
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
    t=Time.now
    @timelast6me[index] = (@timelast6me[index] /6 ) * 5 +  (t - @timelastsayme[index])
    @timelast6me[index] = Initflood if @timelast6me[index] > Initflood + 50
    @timelastsayme[index] = Time.now
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
    t=Time.now
    #~ puts '21 @timelast6say[index]:  index: ' + index.to_s
    @timelast6say[index] = (@timelast6say[index] /6 ) * 5 +  (t - @timelastsay[index])
    @timelast6say[index] = Initflood if @timelast6say[index] > Initflood + 90
    @timelastsay[index] = Time.now
  end

  def saidAndCheckFlood(nick,name,ip,w)
    said(nick,name,ip)
    setLastSay(nick,w)
    return false if name.gsub(/n=/i,'') =~ /^U\d{5}$/#U用户
    return check_flood(nick)
  end
  def saidAndCheckFloodMe(nick,name,ip)
    said_me(nick,name,ip)
    return false if ip=='59.36.101.19'#U用户
    return check_flood_me(nick)
  end
  def chg_ip(nick,ip)
    index = getindex(nick)
    if index == nil #未记录的用户名
      return 1
    end
    @addr[index]=ip
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
 #   return floodreset(nick)
    #index = getindex(nick)
    #@index.delete(nick)
  end
  def getname(nick)
    return @name[getindex(nick)]
  end
  def completename(s)
    return s if !s or s=='' or getindex(s)
    tmp=''
    @index.each_key { |x| (tmp= x;break)if x.to_s =~ /#{Regexp::escape s}/i }
    p '----------completename----'
    p tmp
    return tmp
  end
  def setip(nick,name,ip)
    index = getindex(nick)
    return add(nick,name,ip) if !index
    @addr[index]=ip
  end
  def getip(nick)#记忆的IP
    index = getindex(nick)
    return if !index
    return @addr[index].to_s
  end
  def ims(nick)
    index = getindex(nick)
    return @timelast6say[index]
  end
  def igetlastsay(nick)
    p '60 getlastsay nick: ' , nick
    index = getindex(nick)
    return @timelast6say[index]
  end
end

