#!/usr/bin/env ruby1.9
# coding: utf-8
# 升级到 ruby 1.9 , 只要在bin目录做个 ruby1.9 的可执行文件就行. ubuntu只要执行
# apt-get install ruby1.9 就有
=begin
   * Name: irc.rb
   * Description:     
   * Author: Sevkme@gmail.com
   * Date:  
   * License: GPLV3 
   * 源代码: http://github.com/sevk/kk-irc-bot/ 或 http://code.google.com/p/kk-irc-bot/ 
=end

include Math
require 'date'
require "monitor"
require "readline"
require 'yaml'
load "ipwry.rb"
load 'irc_user.rb'
load 'Dic.rb'
load 'plugin.rb'

#irc类
class IRC
  def initialize(server, port, nick, channel, charset, pass, user)
    loadDic
    @tmp = ''
    @exit = false
    $otherbot_said = nil
    @Motded = false
    @Named = false
    $name_whois = nil
    @server = server
    $need_say_feed=false if @server =~ /oftc/i 

    @port = port
    @nick = nick
    @pass = pass
    @str_user= user
    @channel = channel
    charset='UTF-8' if charset =~ /utf\-?8/i
    @charset = charset
    p BotList_title
    puts "$notitle = #{$notitle}" #不读取url title
    mystart

  end
  
  #kick踢出
  def kick(s)
    send "kick #@channel #{s}"
  end
  def ping(s)
    $Lping = Time.now
    $Lsay = Time.now
    send "PING #{s}"
  end
  #发送notice消息
  def notice(who,sSay,delay=4)
    $otherbot_said=false
    do_after_sec(who,sSay,15,delay)
  end

  #发送msg消息,随机 delay 秒数.
  def msg(who,sSay='',delay=4)
    return if sSay == ''
    $otherbot_said=false
    do_after_sec(who,sSay,0,delay)
  end
  def say(s)
    send "PRIVMSG #{@channel} :#{s}"
    isaid()
  end

  #发送tcp数据,如果长度大于460 就自动截断.
  def send(s)
    s.gsub!(/\s+/,' ')
    if s.bytesize > 450 # ruby 1.9
    #if s.size > 450 # ruby 1.8
      s.chop!.chop! while s.bytesize > 450
      if @charset == 'UTF-8'
        #str.bytes.each_slice(100).map {|s| s.map(&:chr).join }
        #s.scan(/./u)[0,150].join # 也可以用//u
        #while s[-3,1] !~ /[\xe0-\xef]/ and s[-1] > 127 #最后一位不是ASCII,并且最后第三位不是中文字的头
        while not s[-3,1].between?("\xe0","\xef") and s[-1].ord > 127
          s.chop!
        end
      else
        #非utf-8的聊天室就直接截断了
        s=Iconv.conv("#{@charset}//IGNORE","UTF-8//IGNORE",s[0,450])
      end
      s+=' ...'
    else
      s+= Time.now.ch
    end
    @irc.send("#{s.strip}\n", 0)
    $Lsay = Time.now
    puts "----> #{s}".pink
  end

  def connect()
    @irc.close if defined?(@irc)
    @irc = TCPSocket.open(@server, @port)
    send "NICK #{@nick}"
    send @str_user
  end

  #eval
  def evaluate(s)
    #return '操作不安全' if s=~/pass|serv/i
    result = nil
      begin
        p s
        Timeout.timeout(5) {
          result = safe(4) {eval(s).to_s[0,420]}
        }
      rescue Exception => detail
        puts detail.message()
      end
    return result
  end

  #发送字典结果 ,取字典,可以用>之类的重定向,向某人提供字典数据
  def sayDic(dic,from,to,s='')
    direction = ''
    tellSender = false
    pub =true #默认公共消息
    pub =true if dic == 5

    if s=~/(.*?)\s?([#\\\/\@|>])\s?(.*?)$/i #消息重定向
      words=$1;direction=$2.to_s;b7=$3
      if b7
        b7 =$u.completename(b7)
      end
    else
      words=s
    end

    case direction
    when /\||\/|\\/#公共
      sto='PRIVMSG'
    when '>' #小窗
      #sto='PRIVMSG'
      sto='PRIVMSG' ;to=b7;tellSender=true
    when /[#\@]/ #notic
      #sto='PRIVMSG'
      sto='notice' ;to=b7;tellSender=true
    else
      sto='PRIVMSG'
      to=from if !pub
    end

    Thread.new do
      c = words;re=''
      case dic
      when 1 then re = getGoogle(c ,0)
      when 2 then re = getBaidu(c )
      when 3 then re = googleFinance(c )
      when 4 then re = getGoogle_tran(c );c=''
      when 5#拼音
        re = "#{getPY(c)}";c=''; b7= from +':'
      when 6 then re= $str1.match(/(\n.*?)#{Regexp::escape c}(.*\n?)/i)[0]
      when 10 then re = hostA(c)
      when 20 then re = $u.igetlastsay(c).to_s
      when 21 then re = $u.ims(c).to_s
      when 22
        c =$u.completename(c)
        ip = $u.getip(c)
        puts 'ip=' + ip.to_s
        if ip =~ /^gateway\/|mibbit\.com/i#自动whois
          $name_whois = c
          $from_whois = from
          $to_whois = to
          $s_whois = s
          send('whois ' + c)
          return
        end

        re = "#{$u.getname(c)} #{hostA(ip)}"
      when 23
        re = "#{$u.addrgrep(c)}"
        p 'addrgrep ' + c
      when 30
        return if c !~/^[\w\-\.]+$/#只能是字母,数字,-. "#{$`}<<#{$&}>>#{$'}"
        `apt-cache show #{c}`.gsub(/\n/,'~').match(/Version:(.*?)~.{4,16}:(.*?)Description[:\-](.*?)~.{4,16}:/i)
        re="#$3".gsub(/~/,'')
        # gsub(/xxx/){$&.upcase; gsub(/xxx/,'\2,\1')}
        #~ re='未找到软件包' if re.to_s.size<3
      when 40
        c == "" ? re= getTQFromName(from) : re= getTQ(c)
      when 99 then re = Help ;c=''
      when 101 then re = getBaidu_tran(c);c=''
      end
      Thread.exit if re.size < 4

      if sto =~ /notice/i 
        notice(to, "#{b7}:\0039 #{c}\017\0037 #{re}",0)
      else
        msg(to, "#{b7}:\0039 #{c}\017\0037 #{re}",0)
      end
      msg(from,"#{b7}:\0039 #{c}\017\0037 #{re}",0) if tellSender

    end #Thread
  end

  #utf8等乱码检测
  def check_code(s)
    tmp = guess_charset(s)
    if tmp && tmp != @charset && tmp !~ /IBM855|windows-1252/
      if tmp =~ /^gb./i
        s=Iconv.conv("#{@charset}//IGNORE","GB18030//IGNORE",s).strip
      else
        p tmp
        s=Iconv.conv("#{@charset}//IGNORE","#{tmp}//IGNORE",s).strip
      end
      p s
      if s =~ /^:(.+?)!(.+?)@(.+?)\sPRIVMSG\s(.+?)\s:(.*)$/i#需要提示
        from=b1=$1;name=b2=$2;ip=b3=$3;to=b4=$4;say=$5.to_s.untaint
        return if s =~ /action/i
        
        return 'matched err charset' if !$need_Check_code #not match
        send "Notice #{from} :use #{@charset} charset, not #{tmp}"
        send "PRIVMSG #{((b4==@nick)? from: to)} :#{from}:said #{say} in #{tmp} ? But we use #{@charset} !"
        return 'matched err charset'

      end
    end
    return nil
  end

  #处理频道消息,私人消息,JOINS QUITS PARTS KICK NICK NOTICE
  def check_msg(s)
    s= Iconv.conv("#$local_charset//IGNORE","#{@charset}//IGNORE",s) if @charset != $local_charset
    case s.strip
    when /^:(.+?)!(.+?)@(.+?)\sPRIVMSG\s(#{Regexp::escape @nick})\s:(.+)$/i #PRIVMSG me
      from=a1=$1;name=a2=$2;ip=a3=$3;to=a4=$4;sSay=a5=$5
      return if from =~ /freenode-connect|#{Regexp::escape @nick}/i

      if $u.saidAndCheckFloodMe(a1,a2,a3)
        #$u.floodmereset(a1)
        send "PRIVMSG #{a2} :...go to #Sevk for playing... " if rand(10) > 7
        return nil
      end

      if s =~ /help|man|帮助|有什么功能|叫什么|几岁|\?\?/i
        sSay = '`help |'
      end

      tmp = check_dic(a5,a1,a1)
      if tmp.class == Fixnum
        if a5.size < 6 and rand(10) > 6
          msg(from,"#{sSay} ? ,you can try `help")
        end
        $otherbot_said=false
        if rand(10) == 9
          do_after_sec(from, "sleeping...",0,10)
        else
          do_after_sec(to,"#{from}, #{$me.rand(sSay)}",10,15) if defined?$me
        end
      end
    when /^:(.+?)!(.+?)@(.+?)\sPRIVMSG\s(.+?)\s:(.+)$/i #PRIVMSG channel
      nick=from=a1=$1;name=a2=$2;ip=a3=$3;to=a4=$4;sSay=a5=$5
      return if a1==@nick

      #有BOT说话
      $otherbot_said=true if name =~ BotList || nick =~ BotList
      #~ $u.setip(from,name,ip)

      #以我的名字开头
      if sSay =~ /^#{Regexp::escape @nick}[\s,:`](.*)$/i 
        s=$1.to_s.strip

        s = '`' + s if s[0,1] != '`'
        tmp = check_dic(s,from,to)
        case tmp
        when 1
        when 2
          #是title
        else
          puts '是字典消息' if $debug
          if $u.saidAndCheckFloodMe(a1,a2,a3)
            #$u.floodmereset(a1)
            return if to =~ NoFloodAndPlay # 不检测flood和玩bot
            $otherbot_said=true
            send "PRIVMSG #{a1} :sleeping ... in room #Sevk " if rand(10) > 8
            msg to ,"#{from}, play ? ... go to room  #Sevk or #{to}-ot ",0 if rand(10) > 4
            return nil
          end
        end
        return 'msg with my name:.+'
      else
        if a3=~ /^gateway\//i
          msg to ,"#{from}, 代理或网页已经被加入黑名单.",1 if rand(10) > 6
          return
        end
      end

      #禁掉一段时间
      if $u.isBlocked?(from)
        return nil
      end
      tmp = check_dic(sSay,from,to)
      case tmp
      when 1
        #非字典消息
        if sSay =~ /^#{Regexp::escape @nick}\s?,?:?(.*)$/i
          sSay=$1.to_s.strip
          if sSay.bytesize < 3
            send "PRIVMSG #{from} :#{sSay} ? ,you can try `help" if rand(10)>7 
          end
          #puts '消息以我名字开头'
          #$otherbot_said=false
          #do_after_sec(to,"#{from}, #{$me.rand(sSay)}",10,15) if $me
          #`sh sound.sh`
        else
          #$u.said(from,name,ip)
          #$u.setLastSay(from,sSay)
          if $u.saidAndCheckFlood(a1,a2,a3,sSay)
            $u.floodreset(a1)
            return if to =~ NoFloodAndPlay # 不检测flood和玩bot
            msg(a4,"#{a1}: ...flood ? 超过4行或图片请贴到 http://paste.ubuntu.org.cn",4)
            kick a1
            return nil
          end
        end
      when 2
        #是title
      else
        #是字典消息
        if $u.saidAndCheckFloodMe(a1,a2,a3)
          #$u.floodmereset(a1)
          return if to =~ NoFloodAndPlay # 不检测flood和玩bot
          $otherbot_said=true
          send "PRIVMSG #{a1} :sleeping ... in channel #Sevk " if rand(10) > 7
          msg to ,"#{from}, play ? ... go to channel #Sevk or #{to}-ot ",0 if rand(10) > 4
          return nil
        end
      end

    when /^:(.+?)!(.+?)@(.+?)\s(JOIN)\s:(.*)$/i #join
      #:U55555!i=3cbe89d2@gateway/web/ajax/mibbit.com/x-d50dbdfe784bbbd2 JOIN :#sevk
      #@gateway/tor/x-2f4b59a0d5adf051
      nick=from=$1;name=$2;ip=$3;to=$5
      return if from =~ /#{Regexp::escape @nick}/i
      $need_Check_code=false if from =~ BotList_Code
      $need_say_feed=false if from =~ BotList_ub_feed
      $notitle=true if from =~ BotList_title

      $u.add(nick,name,ip)
      #if $u.chg_ip(nick,ip) ==1
        #$u.add(nick,name,ip)
      #end
      renew_Readline_complete($u.all_nick)
    when /^:(.+?)!(.+?)@(.+?)\s(PART|QUIT)\s(.*)$/i #quit
      #:lihoo1!n=lihoo@125.120.11.127 QUIT :Remote closed the connection
      from=$1;name=$2;ip=$3;room=$5.to_s

      $need_Check_code=true if from =~ BotList_Code
      $need_say_feed=true if from =~ BotList_ub_feed
      $notitle=false if from =~ BotList_title

      $u.del(from,ip)
      renew_Readline_complete($u.all_nick)
    when /^(.+?)Notice(.+)$/i  #Notice
      #:ChanServ!ChanServ@services. NOTICE ikk-bot :[#sevk] "此频道目前主要用于BOT测试."

    when /^:(.+?)!(.+?)@(.+?)\sNICK\s:(.+)$/i #Nick_chg
      #:ikk-test!n=Sevk@125.124.130.81 NICK :ikk-new
      nick=$1;name=$2;ip=$3;new=$4
      if $u.chg_nick(nick,new) ==1
        $u.add(new,name,ip)
      end
      renew_Readline_complete($u.all_nick)
    when /^:(.+?)!(.+?)@(.+?)\sKICK\s(.+?)\s(.+?)\s:(.+?)$/i #KICK 
      #:ikk-irssi!n=k@unaffiliated/sevkme KICK #sevk Guest19279 :ikk-irssi\r\n"
      from=$1;chan=$4;tag=$5;reason=$6
      $need_Check_code=true if from =~ BotList_Code
      $need_say_feed=true if from =~ BotList_ub_feed
      $notitle=false if from =~ BotList_title

      renew_Readline_complete($u.all_nick)
    else
      return 1 # not match
    end
  end

  #检测消息是不是敏感或字典消息
  def check_dic(s,from,to)
    case s.strip
    when /^\`?>\s?(.+)$/i #eval
      puts "[4 EVAL #{$1} from #{from}]"
      tmp=evaluate($1.to_s)
      msg to,"#{from}, #{tmp}",0 if tmp
    when /^`h(ost)?\s(.*?)$/i # host
      puts 'host ' + s
      sayDic(10,from,to,$2)
    when /(....)(:\/\/\S+[^\s*])/#类似 http://
      url = $2
      case $1
      when /http/i
        #when  /^(.*)(http:\/\/\S+[^\s*])/i #url_title查询
        #url = $2.match(/http:\/\/\S+[^\s*]/i)[0]
        url = "http#{url}"
        #puts url
        return if $notitle
        return if from =~ BotList
        return if url =~ /past/i 

        $ti = nil
        @ti=Thread.start {
          begin
            $ti = Timeout.timeout(12) { gettitle(url) }
          rescue
            p $!
          end
          if $ti 
            #if $ti =~ TiList || url =~ UrlList
              if s =~ /#{Regexp::escape $ti[0,15]}/i#已经发了就不说了
                puts '已经发了标题 ' + $ti[0,15]
              else
                msg(to,"⇪ title: #{$ti}",0) 
              end
            #end
          end
        }
        @ti.priority = 40
        #@ti.join

      when /ed2k/i
        msg(to,geted2kinfo(url),0)
      end
      return 2
    when /^`(\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3})$/i #IP查询
      puts 'Ip ' + s
      msg to,"#{IpLocationSeeker.new.seek($1)} #{$1}",0
    when /^`tr?\s(.+?)\s?(\d?)\|?$/i  #baidu_tran
      word = $1.to_s
      en = $2 == "0"
      #sayDic(101,from,to,$1)
      Thread.new do
        re = getBaidu_tran(word,en)
        msg to,"#{re}",0 if re.size > 3
      end
    when /^`deb\s(.*)$/i  #aptitude show
      sayDic(30,from,to,$1)
    when /^`?s\s(.*)$/i  #TXT search
      #~ puts 's ' + s
      sayDic(6,from,to,$1)
    when /^[`']help\s?(.*?)$/i #help
      puts 'help ' + s
      sayDic(99,from,to,$1)
    when /^`?(什么是)(.+)[\?？]?$/i #什么是
      w=$2.to_s
      return if w =~/这|那|的|哪/
      sayDic(1,from,to,"define: #{w} |")
    when /^(.*?)[\s:,](.+)是什么[\?？]?$/i #是什么
      #if $u.completename($1) == $1 
      if $1 
        return
      else
        w = $2.to_s
        return if w =~/这|那|的|哪/
        sayDic(1,from,to,"define: #{w} |")
      end
    when /^`ims\s(.*?)$/i  #IMS查询
      puts 'IMS ' + s
      sayDic(21,from,to,$1)
    when /^`flood\s(.*?)$/i  #flood查询
      puts 'flood ' + s
      sayDic(20,from,to,$1)
    when /^`?tt\s(.*?)$/i  # getGoogle_tran
      puts 'getGoogle_tran ' + s
      sayDic(4,from,to,$1)
    when /^`?g\s(.*?)$/i  # Google
      puts 'google ' + s
      sayDic(1,from,to,$1)
    when /^`x\s(.*?)$/i  # plugin
      $otherbot_said=false
      do_after_sec(to,"#{from}, #{$me.rand($1.to_s)}",10,20) if $me
    when /^`?tq\s(.*?)$/i  # 天气
      puts 'TQ ' + s
      sayDic(40,from,to,$1)
    when /^`?d(ef(ine)?)?\s(.*?)$/i#define:
      sayDic(1,from,to,'define: ' + $3)
    when /^`?b\s(.*?)$/i  # 百度
      puts '百度 ' + s
      sayDic(2,from,to,$1)
    when /^`?a\s(.*?)$/i #查某人ip
      sayDic(22,from,to,$1)
    when /^`?f\s(.*?)$/i #查地区
      sayDic(23,from,to,$1)
    when /^`?(大家...(...)?|hi( all)?.?|hello)$/i
      $otherbot_said=false
      do_after_sec(to,from + ', hi .',10,11) if rand(10) > 7
    when /^`?((有人(...)?(吗|不|么|否)((...)?|\??))|test|测试(中)?(.{1,8})?)$/i #有人吗?
      $otherbot_said=false
      do_after_sec(to,from + ', hello .',10,11)
    when /^`?(bu|wo|ni|ta|shi|ru|zen|hai|neng|shen|shang|wei|guo|qing|mei|xia|zhuang|geng|zai)\s(.+)$/i  #拼音
      return nil if s =~ /[^,.?\s\w]/ #只能是拼音或标点
      return nil if s.size < 12
      sayDic(5,from,to,s)
    when /^`i\s?(.*?)$/i #svn
      s1= '我的源代码: http://github.com/sevk/kk-irc-bot/'
      msg to,"#{s1}",0
    when /^`rst(.+)$/i #restart      
      tmp=$1
      #return if from !~ /^(ikk-|WiiW|lkk-|Sevk)$/
      tmp = "%03s" % tmp
      $need_Check_code = tmp[0] != '0'
      $need_say_feed = tmp[1] != '0'
      $notitle = tmp[2] == '0'
      load 'Dic.rb'
      load 'irc_user.rb'
      load "ipwry.rb"
      #load 'plugin.rb'
      loadDic
      msg(to,"restarted, check_charset=#$need_Check_code, get_ub_feed=#$need_say_feed, get_title=#{not $notitle}",0)
    else
      return 1#not match dic_event
    end
  end

  #服务器消息
  def check_irc_event(s)
    case s.strip
    when /^PING :(.+)$/i  # ping
      @irc.send "PONG :#{$1}\n", 0
    when /LAG1982067890/i #LAG
      $lag=Time.new - $Lping
      puts "LAG = #{$lag} 秒" if $lag > 3
    when /^:(.+?)!(.+?)@(.+?)\sPRIVMSG\s.+\s:[\001]PING (.+)[\001]$/i #ctcp ping
      puts "[2 CTCP PING from #{$1}!#{$2}@#{$3} ]"
      send "NOTICE #{$1} :\001PING #{$4}\001"
    when /^:(.+?)!(.+?)@(.+?)\sPRIVMSG\s.+\s:[\001]VERSION[\001]$/i #ctcp
      puts "[3 CTCP VERSION from #{$1}!#{$2}@#{$3} ]"
      send "NOTICE #{$1} :\001VERSION Sevkme@gmail.com Ruby-irc #{Ver} birthday=2008.7.20\001"
    when /^:(.+?)\s(\d+)\s(.*?)\s:(.*)/i#motd , names list
      pos=$2.to_i;tmp=$4.to_s 
      puts pos.to_s + ' ' +  tmp + '  <--- motd'
      if !@Motded
        #376 End of /MOTD
        if pos == 376
          @Motded = true
          $min_next_say=Time.now 
          do_after_sec(@channel,nil,5, 1)
        end
      end
      if !@Named
        case pos
        when 353
          @tmp += ' ' + tmp
        when 366#End of /NAMES list.
          from = @tmp
          puts from
          $need_Check_code=false if from =~ BotList_Code
          $need_say_feed=false if from =~ BotList_ub_feed
          $notitle=true if from =~ BotList_title

          @Named = true 
          Readline.completion_case_fold = true
          renew_Readline_complete(@tmp.gsub('@','').split(' '))
          Readline.completion_append_character = ': '

          puts "是否检测乱码= #{$need_Check_code}"
          puts 'feed功能= ' + $need_say_feed.to_s
          puts 'notitle= ' + $notitle.to_s 
        end 
      end
      if pos == 901 #901 是 nick 验证完成.
        $min_next_say=Time.now 
        do_after_sec(@channel,nil,7,1)
      end

      #自动 whois 返回
      if $name_whois && pos == 311
        ip= tmp
        $u.chg_ip($name_whois,ip)
        $name_whois = nil
        sayDic(22,$from_whois,$to_whois,$s_whois)
      end 
      #:zelazny.freenode.net 353 ikk-bot = #sevk :ikk-bot @Sevkme @[ub]
    when /^:(.+?)\sTOPIC\s(.+)\s:(.+)$/i#topic
      from=$1;chan=$2;topic=$3
      puts s
      #:Wii-2!n=Sevk@60.163.53.134 TOPIC #sevk :"此频道目前主要用于闲聊和调戏BOT."

      #QUIT name :niven.freenode.net irc.freenode.net
      #Netsplit hubbard.freenode.net <-> irc.freenode.net
    when /^:(.+?)\sMODE\s(.+)\+(.+)$/i#mode
      #:services. MODE ikk-bot :+e
      #:ChanServ!ChanServ@services. MODE #sevk +o ikk-bot
      puts s
    when /^ERROR\s:(.*?):\s(.*?)$/i # Closeing
      puts s
      myexit if s =~ /:Closing Link:/i
    else
      return nil#not match 
    end #end case
    return 'matched'
  end #end irc_event
  #写入日志
  def save_log(s)

  end

  #检测消息是不是服务器消息,乱码检测或字典消息
  def handle_server_input(s)
    return if check_irc_event(s) #服务器消息
    return if check_code(s) #乱码
    puts highlighted(s) #高亮显示消息
    save_log(s)#写入日志
    return if not $bot_on #bot 功能
    s=s.force_encoding("utf-8")
    return if check_msg(s).class != Fixnum #字典消息
  end

  #显示高亮
  def highlighted(s)
    s=s.force_encoding("utf-8")
    case s
    when /^:(.+?)!(.+?)@(.+?)\s(.+?)\s:(.+)$/i
      from=$1;name=$2;ip=$3;mt=msgto=$4;sy=$5
      if mt =~ /^priv/i
        mt= ''
      else
        mt= mt.green 
      end
      sy=sy.yellow if mt =~ /\s#{Regexp::escape @nick}/i
      re= "#{from} #{mt} #{sy}"
      re = re.utf8_to_gb if $local_charset !~ /UTF-8/i 
      return re
    else
      return s.blue
    end
  end

  def isaid(second=3)
    $min_next_say=Time.now + Minsaytime + second
  end

  #延时发送
  def do_after_sec(to,sSay,flg,second)
    #puts "need_do #{flg} #{second}"
    Thread.new do
      flag=flg
      if Time.now < $min_next_say
        puts '还没到下次说话的时间'
        Thread.exit
      else
        isaid(second)
      end
      if second < Delay_do_after
        sleep second
      else
        sleep rand(second-Delay_do_after) + Delay_do_after
      end
      Thread.exit if $otherbot_said

      case flag
      when 0
        send "PRIVMSG #{to} :#{sSay}"
      when 5 #发送密码
        send "PRIVMSG nickserv :id #{@pass}"
        $pass=@pass=rand(100)
        $min_next_say = Time.now
        do_after_sec(@channel,nil,7,11)
      when 7
        send "JOIN #sevk"
        send "JOIN #{@channel}"
        #send "privmsg #{@channel}  :\001ACTION 我不是机器人#{0.chr} "
      when 10#打招呼回复
        tmp = ((DateTime.parse('2009-01-26 00:00:00+08:00')-DateTime.now)*24*60*60).round
        if tmp < 0 #不用显示倒计时
          return if sSay =~ /\s$/
          send "PRIVMSG #{to} :#{sSay} \0039 #{chr_hour} \017"
          return
        end
        case tmp
        when 0..60
          tmp="还有#{tmp}秒"
        when 61..3600
          tmp="还有#{tmp/60}分钟"
        when 3601..86400
          tmp="还有#{tmp/60/60}小时"
        else
          tmp="还有#{tmp/60/60/24}天"
        end
        send "privmsg #{to} :#{sSay} #{chr_hour} #{Time.now.strftime('[%H:%M]')} \0039新年快乐，离除夕0点#{tmp}\017"
      when 20#notice
        send "NOTICE #{to} :#{sSay}"
      end
    end #Thread
  end

  def renew_Readline_complete(w)
    Readline.completion_proc = proc {|word| w.grep(/^#{Regexp.quote word}/) }
  end

  #检测用户输入,实现IRC客户端功能.
  def iSend()
    while true
      Thread.pass
      s = Readline.readline('[' + @channel + '] ', true)
      #s = Readline.readline('', true)
      Thread.pass
      next if !s
      #lock.synchronize do
        case s
        when /^:q\s?(.*?)$/i #:q退出
          tmp = $1.to_s
          send 'quit optimize ' + tmp
          p 'quit...'
          sleep 3
          myexit()
          exit
        when /^\/msg\s(.+?)\s(.+)$/
          who = $1;s=$2
          send "privmsg #{who} :#{s.strip}"
        when /^\/ns\s+(.*)$/ #发送到nick serv
          send "privmsg nickserv :#{$1.strip}"
        when /^[\/]/ # 发送 RAW命令
          send s.gsub(/^[\/:]/,"")
        when /^`/
          check_dic(s,@nick,@channel)
        else
          say s
        end
      #end
    end
  end
  def mystart
    $u = YAML.load_file("person_#{ARGV[0]}.yaml") rescue nil
    $u = ALL_USER.new if ! $u 
    $u.init_pp
    puts $u.all_nick.count.to_s + ' nicks loaded from yaml file.'.red
  end

  def myexit
    saveu
    puts 'exiting...'.yellow
    @exit = true
  end
  
  def timer_start
    timer1 = Thread.new do#timer 1 , interval = 2600
      n = 0
      loop do
        sleep(700 + rand(850))
        p Time.now
        n+=1
        next if n%2 ==0
        next unless (8..24) === Time.now.hour
        saveu if n%7 ==0
        next unless $need_say_feed
        begin
          tmp = get_feed.to_s
          if tmp.size > 4
            msg(@channel,tmp,0)  
          end
          #msg('#Sevk',tmp,0) if Time.now.hour.between?(9,24)
        rescue Exception => detail
          puts "#{detail.message()} in timer1"
          puts $@
        end
      end
    end
  end

  #主循环
  def main_loop()
    Thread.start{ iSend }

    while true
      Thread.pass
      #ready = select([@irc, $stdin], nil, nil, nil)
      Thread.exit if @exit
      ready = select([@irc], nil, nil, nil)
      next if !ready
      for s in ready[0]
        if s == @irc
          next if @irc.eof rescue (p $!.message;p $@)
          handle_server_input(@irc.gets.strip) rescue (p $!.message;p $@)
        end
      end
    end

  end
end

load 'default.conf'
load ARGV[0] if ARGV[0]

irc = IRC.new($server,$port,$nick,$channel,$charset,$pass,$user)
#while true
  irc.connect()
  irc.timer_start
  irc.main_loop()
  #p 'sleep ..'
  #sleep 3600 * 6
#end

# vim:set shiftwidth=2 tabstop=2 expandtab textwidth=79:

