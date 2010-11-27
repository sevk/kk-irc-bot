#!/usr/bin/env ruby
# coding: utf-8
# Sevkme@gmail.com

require 'iconv'
#为字符串添加一些方法
class String
  def utf8
    self.force_encoding("utf-8")
  end
  def gb
    self.force_encoding("gb18030")
  end
  def gb_to_utf8
    Iconv.conv("UTF-8//IGNORE","GB18030//IGNORE",self).to_s
  end
  def utf8_to_gb
    Iconv.conv("GB18030//IGNORE","UTF-8//IGNORE",self).to_s
  end
  def decode64
    Base64.decode64 self
  end
  def encode64
    Base64.encode64 self
  end
  def ii(s=['☘',"\322\211"][rand(2)])
    self.split(//u).join(s)
  end
  def addTimCh
    self + Time.now.hm.to_s
  end

  #整理html里的 &nbsp; 等转义串，需要安装
  def unescapeHTML
    HTMLEntities.new.decode(self) rescue self
  end
end

begin
  #apt-get install rubygems
  require 'rubygems' #以便引用相关的库
  #gem install htmlentities
  require 'htmlentities'
  #gem install mechanize
  require 'mechanize'

rescue LoadError
  s="载入库错误,命令:\napt-get install rubygems; #安装ruby库管理器 \ngem install htmlentities; #安装htmlentities库\n否则html &nbsp; 之类的字符串转化可能失效.  \n\n"
  s = s.utf8_to_gb if os_family == 'windows'
  puts s
  puts $!.message
  puts $@[0]
end

begin
  require 'charguess.so'
rescue LoadError
  p 'charguess.so not found'
end
require 'time'
require 'timeout'
require 'open-uri'
require 'uri'
require 'net/http'
require 'rss'
require 'base64'
require 'resolv'
require 'yaml'
load 'do_as_rb19.rb'
load 'color.rb'

#todo http://www.sharej.com/ 下载查询
#todo http://netkiller.hikz.com/book/linux/ linux资料查询
$old_feed_date = nil unless defined?$old_feed_date
$_time=0 if not defined?$_time
$kick_info = '请勿Flood，超过4行贴至 http://code.bulix.org 图片帖至 http://kimag.es'

Help = '我是 kk-irc-bot ㉿ s 新手资料 g google d define `new 取论坛新贴 `deb 包查询 tt google翻译 `t 词典 > x=1+2;x+=1 计算x的值 > gg 公告 > b 服务器状态 `a 查某人地址 `host 查域名 `i 机器人源码. 末尾加入|重定向,如 g ubuntu | nick'
Ver='v0.31' unless defined?(Ver)
UserAgent="kk-bot/#{Ver} (X11; U; Linux i686; en-US; rv:1.9.1.2) Gecko/20090810 Ubuntu/9.10 (karmic) kk-bot/#{Ver}"

CN_re = /(?:\xe4[\xb8-\xbf][\x80-\xbf]|[\xe5-\xe8][\x80-\xbf][\x80-\xbf]|\xe9[\x80-\xbd][\x80-\xbf]|\xe9\xbe[\x80-\xa5])+/n

Http_re= /http:\/\/\S*?[^\s<>\\\[\]\{\}\^\`\~\|#"%]/

Minsaytime= 5
puts "Min say time=#{Minsaytime}"
$min_next_say = Time.now
$Lsay=Time.now; $Lping=Time.now
$last_save = Time.now - 110
$proxy_status_ok = false

puts "$SAFE= #$SAFE"
NoFloodAndPlay=/\-ot|arch|fire/i
$botlist=/bot|fity|badgirl|pocoyo.?.?|iphone|\^?[Ou]_[ou]|MadGirl/i
$botlist_Code=/badgirl|\^?[Ou]_[ou]/i
$botlist_ub_feed=/crazyghost|\^?[Ou]_[ou]/i
$botlist_title=/raybot|\^?[Ou]_[ou]/i
#$tiList=/ub|deb|ux|ix|win|beta|py|ja|qq|dn|pr|qt|tk|ed|re|rt/i
$urlList = $tiList = /ubunt|linux|debia|java|python|ruby|perl|vim|emacs/i
$urlProxy=/\.ubuntu\.(org|com)\.cn|linux\.org|ubuntuforums\.org|\.youtube\.com/i
$urlNoMechanize=/google|\.cnbeta\.com|combatsim\.bbs\.net\/bbs|wikipedia\.org|wiki\.ubuntu/i


def URLDecode(str)
  #str.gsub(/%[a-fA-F0-9]{2}/) { |x| x = x[1..2].hex.chr }
  URI.unescape(str)
end

def URLEncode(str)
  #str.gsub(/[^\w$&\-+.,\/:;=?@]/) { |x| x = format("%%%x", x.ord) }
  URI.escape(str)
end

def unescapeHTML(str)
  HTMLEntities.new.decode(str) rescue str
end

#字符串编码集猜测
def guess_charset(str)
  s=str.force_encoding("ASCII-8BIT").gsub(/[\x0-\x7f]/,'')
  return if s.bytesize < 4
  while s.bytesize < 25
    s << s
  end
  return guess(s)
end

if defined?CharGuess
  def guess(s)
    CharGuess::guess(s)
  end
else
  #第二种字符集猜测库
  begin
    require 'rchardet'
  rescue LoadError
    s="载入库错误,命令:\napt-get install rubygems; #安装ruby库管理器 \ngem install rchardet; #安装字符猜测库\n否则字符编码检测功能可能失效. \n\n"
    s = s.utf8_to_gb if os_family == 'windows'
    puts s
    puts $!.message
    puts $@[0]
    exit
  end
  def guess(s)
    CharDet.detect(s)['encoding'].upcase
  end
end

#'http://linuxfire.com.cn/~sevk/UBUNTU新手资料.php'
def loadDic()
  $str1 = IO.read('UBUNTU新手资料.txt') rescue ''
  puts 'Dic load [ok]'
end

#保存缓存的users
def saveu
  return if Time.now - $last_save < 120 rescue nil
  $last_save = Time.now
  File.open("person_#{ARGV[0]}.yaml","w") do|io|
    YAML.dump($u,io)
  end
  puts ' save u ok'.red
end

#使用安全进程进行eval操作,参数level是安全级别.
def safe(level)
  result = nil
  Thread.start {
    $SAFE = level
    result = yield rescue $!.message
  }.join
  result
end

def get_Atom(url= 'http://forum.ubuntu.org.cn/feed.php',not_re = true)
  buffer = open(url, 'UserAgent' => 'Ruby-AtomReader').read
  document = Document.new(buffer)
  elements = REXML::XPath.match(document.root, "//atom:entry/atom:title/text()","atom" => "http://www.w3.org/2005/Atom")
  titles = elements.map {|el| el.value }
  puts titles.join("\n")
end

def get_Atom_n(url= 'http://forum.ubuntu.org.cn/feed.php',not_re = true)
  buffer = open(url, 'UserAgent' => 'Ruby-AtomReader').read
  #Nokogiri.new()
  document = Nokogiri::XML(buffer)
  elements = document.xpath("//atom:entry/atom:title/text()","atom" => "http://www.w3.org/2005/Atom")
  titles = elements.map {|e| e.to_s}
  puts titles.join("\n")
end

#取ubuntu.org.cn的 feed.
def get_feed(url= 'http://forum.ubuntu.org.cn/feed.php',not_re = true)
  feed = begin
    Timeout.timeout(20) {
      RSS::Parser.parse(url)
    }
  rescue Timeout::Error => e
    p e.message
    #return e.message[0,60] + ' . IN `new '
    return
  end

  $ub=nil
  begin
    feed.items.each { |i|
      link = i.link.href
      des = i.content.to_s
      #date = i.updated.content
      $date = link
      ti = i.title.content.to_s

      next if ti =~ /Re:/i && not_re
      puts i.updated.content
      $ub = "新⇨ #{ti} #{link} #{des}"
      break
    }
  rescue
    p $!.message
    p $@[0]
  end

  if $old_feed_date == $date || (!$ub)
    #link = feed.items[0].link.href
    #ti = feed.items[0].title.content
    ##date = feed.items[0].updated.content
    #$date = link
    #des = feed.items[0].content
    #$ub = "新⇨ #{ti} #{link} #{des}"
    $ub = "呵呵,逛了一下论坛,暂时无新贴.只有Re: ."
    $ub = '' if rand > 0.2
  else
    $old_feed_date = $date
  end

  $ub.gsub!(/\s+/,' ')
  return $ub.gsub(/<.+?>/,' ').unescapeHTML.gsub(/<.+?>/,' ').unescapeHTML
end

#google 全文翻译,参数可以是中文,也可以是英文.
def getGoogle_tran(word)
  if word.force_encoding("ASCII-8BIT") =~ CN_re #有中文
    flg = 'zh-CN%7cen'
    #flg = '#auto|en|' + word ; puts '中文>英文'
  else
    flg = 'auto%7czh-CN'
    #flg = '#auto|zh-CN|' + word
  end
  word = URI.escape(word)
  #url = "http://66.249.89.100/translate_t?hl=zh-CN#{flg}"
  url = "http://translate.google.com/translate_a/t?client=firefox-a&text=#{word}&langpair=#{flg}&ie=UTF-8&oe=UTF-8"
  uri = URI.parse(url)
  uri.open(
           'Accept'=>'image/gif, image/x-xbitmap, image/jpeg, image/pjpeg, application/x-shockwave-flash, */*',
           'Accept'=>'text/html',
           'Referer'=> URI.escape(url)
           #'Accept-Language'=>'zh-cn',
           #'Cookie' => cookie,
           #'Range' => 'bytes=0-8000',
           #'User-Agent'=> UserAgent
           ){
    |f|
    return f.read.match(/"trans":"(.*?)","/)[1]
    #re = f.read[0,5059].force_encoding('utf-8').gsub(/\s+/,' ').gb_to_utf8
    #re.gsub!(/<.*?>/i,'')
    #return unescapeHTML(re)
  }

  #Net::HTTP.start('translate.google.com') {|http|
  #resp = http.get("/translate_a/t?client=firefox-a&text=#{word}&langpair=#{flg}&ie=UTF-8&oe=UTF-8", nil)
  #p resp.body
  #return resp.body
  #}
end

#dict.cn
def dictcn(word)
  word = word.utf8_to_gb
  url = 'http://dict.cn/mini.php?q=' + word
  url = URI.escape(url)
  uri = URI.parse(url)
  res = nil
  uri.open(
  'Accept'=>'image/gif, image/x-xbitmap, image/jpeg, image/pjpeg, application/x-shockwave-flash, */*',
  'Accept'=>'text/html',
  'Referer'=> URI.escape(url),
  'Accept-Language'=>'zh-cn',
  #'Cookie' => cookie,
  'Range' => 'bytes=0-9000',
  'User-Agent'=> UserAgent
  ){ |f|
    re = f.read[0,5059].force_encoding('utf-8').gsub(/\s+/,' ').gb_to_utf8
    re.gsub!(/<script.*?<\/script>/i,'')
    re.gsub!(/<.*?>/i,'')
    re.gsub!(/.*?Define /i,'')
    re.gsub!(/加入生词本.*/,'')
    return re.unescapeHTML + ' << Dict.cn'
  }
rescue
  return $!.message
end

def url_fetch(uri_str, limit = 3)
  # You should choose better exception.
  raise ArgumentError, 'HTTP redirect too deep' if limit == 0

  response = Net::HTTP.get_response(URI.parse(uri_str))
  case response
  when Net::HTTPSuccess     then response
  when Net::HTTPRedirection then fetch(response['location'], limit - 1)
  else
    response.error!
  end
end

#取标题,参数是url.
def gettitle(url,proxy=nil,mechanize=true)
  url.force_encoding('utf-8')
  title = ''
  charset = ''
  flag = 0
  istxthtml = false
  if url =~ /[\u4E00-\u9FA5]/u
    url = URI.encode(url)
  end

  mechanize = false if url =~ $urlNoMechanize
  proxy = true if url =~ $urlProxy
  proxy = false if ! $proxy_status_ok
  print ' mechanize:' , mechanize , ' ' , url ,10.chr

  #p url =~ $urlProxy
  #用代理加快速度
  if mechanize
    if url =~ /%[A-F0-9]/
      url = URI.decode(url)
      puts url
    end
    agent = Mechanize.new
    agent.user_agent_alias = 'Linux Mozilla'
    #agent.user_agent_alias = 'Windows IE 7'
		print 'use proxy in gettitle ',$proxy_addr,$proxy_port,10.chr
    if proxy
      agent.set_proxy($proxy_addr,$proxy_port)
    end
    agent.max_history = 1
    agent.open_timeout = 14
    #agent.cookies
    #agent.auth('^k^', 'password')
    begin
      page = agent.get(url)
      #p page.header['content-type'].match(/charset=(.+)/)[1] rescue (p $!.message + $@[0])
			#p 'get page ok'
      #Content-Type
      if page.class != Mechanize::Page
				puts 'no page'
				return
			end
			title = page.title
			charset= guess_charset(title)
			if charset and charset != 'UTF-8'
				#p charset
				charset='GB18030' if charset =~ /^gb/i
				title = Iconv.conv("UTF-8","#{charset}//IGNORE",title) rescue title
			end
			title = unescapeHTML(title)# rescue title
			title = URI.decode(title)
			return title
			rescue Timeout::Error
      return 'time out . IN gettitle '
    rescue Exception => e
      p $!.message + $@[0]
      return $!.message[0,60] + ' . IN gettitle'
    end
  end

    tmp = begin #加入错误处理
      Timeout.timeout(13) {
        $uri = URI.parse(url)
        #$uri.open{|f| puts f.read.match(/title.+title/i)[0]};exit
        $uri.open(
        'Accept'=>'text/html , application/*',
        #'Cookie' => 'a',
        'Range' => 'bytes=0-9999',
        #'Cookie' => cookie,
        #'Range' => 'bytes=0-9999',
        'User-Agent'=> UserAgent
        ){ |f|
          istxthtml= f.content_type =~ /text\/html/i
          charset= f.charset          # "iso-8859-1"
          f.read[0,4000].gsub(/\s+/,' ')
        }
      }
    rescue Timeout::Error
      return 'time out . IN gettitle '
    rescue
      p $!.message + $@[0]
      #if $!.message == 'Connection reset by peer' && $proxy_status_ok
        #return Timeout.timeout(12){gettitle(url,true)}
      #end
      return $!.message[0,60] + ' . IN gettitle'
    end

    return unless istxthtml

    tmp.match(/<title.*?>(.*?)<\/title>/i) rescue nil
    title = $1.to_s

    if title.bytesize < 1
      if tmp.match(/meta\shttp-equiv="refresh(.*?)url=(.*?)">/i)
        p 'refresh..'
        return Timeout.timeout(13){gettitle("http://#{$uri.host}/#{$2}")}
      end
    end

    return if title =~ /index of/i

    if tmp =~ /<meta.*?charset=(.+?)["']/i
      charset=$1 if $1
    end
    if charset =~ /^gb/i
      charset='GB18030'
    end

    #tmp = guess_charset(title * 2).to_s
    #charset = 'gb18030' if tmp == 'TIS-620'
    #charset = tmp if tmp != ''
    #return title.force_encoding(charset)

    if charset != 'UTF-8'
      charset='GB18030' if charset =~ /^gb/i
      title = Iconv.conv("UTF-8","#{charset}//IGNORE",title) rescue title
    end
    title = unescapeHTML(title) rescue title
    puts title.blue
    title
end

def gettitleA(url,from)
	url = "http#{url}"
	puts url.blue
	return if from =~ $botlist
	return if url =~ /past|imagebin\.org|\.iso$/i
	return if $last_ti == url
	$last_ti = url

		ti= gettitle(url)
		return if ti =~ /\.log$/i
		return if ti !~ $tiList and url !~ $urlList

		#检测是否有其它取标题机器人
		Thread.new do
			myti = ti
			sleep 12
			if $u.has_said?(myti)
				p 'has_said = true'
				$saytitle -=1 if $saytitle > 0
			else
				p 'has_said = false'
				$saytitle +=0.4 if $saytitle < 1
			end
		end
		return if $saytitle < 1
		if ti
			ti.gsub!(/Ubuntu中文论坛 • 登录/,'对不起,感觉是个水贴')
			#p 'gettitle ok..'
			return "⇪ title: #{ti}"
		end
end

def getPY(c)
  c=' '+ c
  c.gsub!(/\sfirefox(.*?)\s/i,' huohuliulanqi ')
  c.gsub!(/\subuntu/i,' wu ban tu ')
  c.gsub!(/\sopen(.*?)\s/i,' ')
  c.gsub!(/\s(xubuntu|fedora)/i,' ')
  c.gsub!(/\s[A-Z](.*?)\s/,' ')
  if c =~ /\skubuntu/i
    needAddKub=true
    c.gsub!(/\skubuntu/i,' ')
  end
  re = google_py(c)
  re = re + ' Kubuntu' if needAddKub==true
  re.gsub!(/还原/i,'换源')

  if re=~ CN_re#是中文才返回
    return re
  end
end

def getTQFromName(nick)
  ip=$u.getip(nick).to_s
  p 'getip=' + ip
  tmp=getProvince(ip).to_s
  puts 'get province:' + tmp.to_s
  getTQ(tmp)
end

def getTQ(s)
  getGoogle(s + ' tq',0)
end

def encodeurl(url)
  if url =~ /[\u4E00-\u9FA5]/
    url = URI.encode(url)
  end
  url
end

def google_py(word)
    re=''
    url = 'http://www.google.com/search?hl=zh-CN&oe=UTF-8&q=' + word.strip
    url = encodeurl(url)
    url_mini = encodeurl('http://www.google.com/search?q=' + word.strip)

    open(url,
    'Referer'=> url,
    'Accept-Encoding'=>'deflate',
    'User-Agent'=> UserAgent
    ){ |f|
      html=f.read.gsub(/\s+/,' ')
      html.match(/是不是要找.*<em>(.*?)<\/em>/i)
      return unescapeHTML($1.to_s)
    }
end

def getGoogle(word,flg)
    re=''
    url = 'http://www.google.com/search?hl=zh-CN&oe=UTF-8&q=' + word.strip
    url = encodeurl(url)
    url_mini = encodeurl('http://www.google.com/search?q=' + word.strip)

    open(url,
    #'Accept'=>'image/gif, image/x-xbitmap, image/jpeg, image/pjpeg, application/x-shockwave-flash, */*',
    'Referer'=> url,
    #'Accept-Language'=>'zh-cn',
    'Accept-Encoding'=>'deflate',
    'User-Agent'=> UserAgent
    ){ |f|
      html=f.read.gsub(/\s+/,' ')
        matched = true
        case html
        when /相关词句：(.*?)网络上查询(.*?)(https?:\/\/\S+[^\s*])">/i#define
          tmp = $2.to_s + " > " + $3.to_s.gsub(/&amp;.*/i,'')
          tmp += ' ⋙ SEE ALSO ' + $1.to_s if rand(10)>5 and $1.to_s.size > 2
        when /专业气象台|比价仅作信息参考/
          tmp = html.match(/resultStats.*?\/nobr>(.*?)(class=hd>搜索结果|Google\s+主页)/i)[1]
        when /calc_img\.gif(.*?)Google 计算器详情/i #是计算器
          tmp = '<' +$1.to_s + ' Google 计算器' #(.*?)<li>
        else
          matched = false
        end
        #p;puts html.match(/搜索用时(.*?)搜索结果<\/h2>(.*?)网页快照/i)[0]
        if matched or html =~ /搜索用时(.*?)搜索结果<\/h2>(.*?)网页快照/i
          if !matched
            tmp =$2.gsub(/<cite>.+<\/cite>/,' ' + url_mini)
            tmp1=$1
          end
          tmp.gsub!(/(.+?)您的广告/,'')
          if tmp=~/赞助商链接/
            tmp.gsub!(/赞助商链接.+?<ol.+?<\/ol>/,' ')
          end
          tmp.gsub!(/更多有关货币兑换的信息。/,"")
          tmp.gsub!(/<br>/i," ")
          #puts tmp + "\n"
          case word
          when /^tq|tq$|天气$|tianqi$/i
            #puts '天气过滤' + tmp.to_s
            tmp.gsub!(/.*?<table class="ts std">/i,'')
            tmp.gsub!(/alt="/,'>')
            tmp.gsub!(/"?\s?title=|right/,'<')
            tmp.gsub!(/\s\/\s/,"\/")
            tmp.gsub!(/级/, '级 ' )
            tmp.gsub!(/今日\s+/, ' 今日' )
            tmp.gsub!(/<\/b>/, ' ')
            tmp.gsub!(/添加到(.*?)当前：/,' ')
            tmp.gsub!(/相关搜索.*?\-/,' ')
            #tmp.gsub!(/北京市专业气象台(.*)/, '' )
            tmp=tmp.match(/.+?°C.+?°C.+?°C/)[0]
            tmp.gsub!(/°C/,'度 ')
          end
          tmp.gsub!(/(.*秒）)|\s+/i,' ')
          if tmp.bytesize > 30 || word =~ /^.?13.{9}$/ || tmp =~ /小提示/ then
            re=tmp
          else
            #puts "tmp.bytesize=#{tmp.bytesize} => 是普通搜索"
            do1=true
          end
        else
          do1=true
        end
        if do1
          #puts '+普通搜索+'
          html.match(/搜索结果(.*?)(https?:\/\/[^\s]*?)">?(.*?)<div class="s">(.*?)<em>(.*?)<br><cite>/i)
          #~ puts "$1=#{$1}\n$2=#{$2}\n$3=#{$3}\n$4=#{$4}\n$5=#{$5}"
          #url= $2.to_s
          re = $4.to_s + $5.to_s #+ $3.to_s.sub(/.*?>/i,'')

          #if url =~ /https?:\/\/(.*?)(https?:\/\/.+?)/i
            #puts '清理二次http'
            #url=$2.to_s
          #end
          re = url_mini + ' ' + re
        end
      return nil if re.bytesize < 3
      re.gsub!(/<.*?>/i,'')
      re.gsub!(/\[\s翻译此页\s\]/,'')
      re= unescapeHTML(re)
    }

    return unless re
    return if re.bytesize < url_mini.bytesize + 3
    return re
end

#ed2k
def geted2kinfo(url)
  url.match(/^:\/\/\|(\w+?)\|(\S+?)\|(.+?)\|.*$/)
  return if $1 == 'server'
  $ti = "#{URLDecode($2.to_s)} , #{ '%.2f' % ($3.to_f / 1024**3)} GB"
  $ti.gsub!(/.*\]\./,'')
  "⇪ #{unescapeHTML($ti)}"
end

def getBaidu(word)
  url=  'http://www.baidu.com/s?cl=3&ie=UTF-8&wd='+word
  if url =~ /[\u4E00-\u9FA5]/
    url = URI.encode(url)
  end
  p url
  open(url,
  'Accept'=>'image/gif, image/x-xbitmap, image/jpeg, image/pjpeg, application/x-shockwave-flash, */*',
  'Referer'=> url,
  'Accept-Language'=>'zh-cn',
  'Accept-Encoding'=>'deflate',
  'User-Agent'=> UserAgent,
  'Host'=>'www.baidu.com',
  'Connection'=>'close'
  ) {|f|
      html=f.read().gsub!(/\s/,' ')
      re = html.match(/ScriptDiv(.*?)(http:\/\/\S+[^\s*])(.*?)size=-1>(.*?)<br><font color=#008000>(.*?)<a\ href(.*?)(http:\/\/\S+[^\s*])/i).to_s
      re = $4 ; a2=$2[0,120]
      re= re.unescapeHTML.gsub(/<.*?>/i,'')[0,330]
      $re = a2 + ' ' +  re
      $re = Iconv.conv("UTF-8//IGNORE","gb2312//IGNORE",$re).to_s[0,980]
  }
  $re
end

def getBaidu_tran(word,en=true)
    url= 'http://www.baidu.com/s?cl=3&ie=UTF-8&wd='+word+'&ct=1048576'
    if url =~ /[\u4E00-\u9FA5]/
      url = URI.encode(url)
    end
    open(url,
    'Accept'=>'image/gif, image/x-xbitmap, image/jpeg, image/pjpeg, application/x-shockwave-flash, */*',
    'Referer'=> url,
    'Accept-Language'=>'zh-cn',
    'Accept-Encoding'=>'deflate',
    'User-Agent'=> UserAgent,
    'Host'=>'www.baidu.com',
    'Connection'=>'close',
    'Cookie'=>'BAIDUID=EBBDCF1D3F9B11071169B4971122829A:FG=1; BDSTAT=172f338baaeb951db319ebc4b74543a98226cffc1f178a82b9014a90f703d697'
    ) {|f|
        html = f.read()
        html = html.gb_to_utf8.gsub(/\s+/,' ')
        re = ' <' + html.match(/class="wd"(.+?)<script>pronu/i)[1].to_s + ' '
        re += html.match(/class="explain">(.+?)<script/i)[1]
        re.gsub!(/<script\s?.+?>.+?<\/script>/i,'')
        re = re[0,600]
        re.gsub!(/&nbsp/,' ')
        re = unescapeHTML(re)
        re.gsub!(/<.*?>/,'')
        $re = re.gsub(/>pronu.+?中文翻译/i,' ')
        $re.gsub!(/以下结果由.*?提供词典解释/,' ')
        $re.gsub!(/部首笔画部首.+?基本字义/,' 基本字义: ')
        if en
          $re.gsub!(/基本字义.*?英文翻译/,': ')
        end
    }
    $re
end

#为Time类加入hm方法,返回格式化后的时和分
class Time
  $last_time_min = Time.now
  def hm
    if Time.now - $last_time_min > 900
      $last_time_min = Time.now
      Time.now.strftime(' %H:%M')
    end
  end
  #ch,小时字符. '㍘' = 0x3358
  def ch
    if Time.now - $last_time_min > 900
      $last_time_min = Time.now
      ' ' +
      if RUBY_VERSION < '1.9'
        "\xE3\x8D"+ (Time.now.hour + 0x98).chr
      else
        (Time.now.hour + 0x3358).chr("UTF-8")
      end
    end
  end
end


#取IP地址的具体位置,参数是IP
def getaddr_fromip(ip)
  hostA(ip,true)
end

#域名转化为IP
def host(domain)
  return 'IPV6' if domain =~ /^([\da-f]{1,4}(:|::)){1,6}[\da-f]{1,4}$/i
  domain.gsub!(/\/.*/i,'')
  return domain if not domain.include?('.')
  return Resolv.getaddress(domain) rescue domain
end
def getProvince(domain)#取省
  hostA(domain).gsub(/^.*(\s|省)/,'').match(/\s?(.*?)市/)[1]
end

#取IP或域名的地理位置
#hostA('www.g.cn',true)
def hostA(domain,hideip=false)#处理IP 或域名
  return nil if !domain
  if domain=~ /^(\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3})$/
    tmp = $1
  else
    tmp = host(domain)
  end
  if hideip
    tmp = IpLocationSeeker.new.seek(tmp) rescue tmp
  else
    tmp = tmp + '-' + IpLocationSeeker.new.seek(tmp) rescue tmp
  end
  tmp.gsub!(/CZ88\.NET/i,'')
  tmp.gsub!(/IANA/i,'不在宇宙')
  tmp.gsub(/\s+/,'').to_s + ' '
end

#eval
def evaluate(s)
  l=4
  l=0 if s =~ /^(b|gg)$/i
  Timeout.timeout(4){
    return safe(l){eval(s).to_s[0,400]}
  }
rescue Timeout::Error
  return 'Timeout Error'
rescue Exception => detail
  return detail.message
end

def onemin
  60
end
def onehour
  3600
end
def oneday
  86400
end

unless defined?Time._now
  p 'redefine Time.now'
  class Time
    class << self
      alias _now now if not defined?_now
      def now
        _now - $_time
      end
    end
  end
end

#返回roll
def roll
  "掷出了随机数: #{rand(101)} "
end

#返回uptime
def b
  `uptime`
end

#每日一句英语学习
def osod
  return
  agent = Mechanize.new
  agent.user_agent_alias = 'Linux Mozilla'
  agent.max_history = 1
  agent.open_timeout = 10
  agent.cookies
  #url = 'http://ppcbook.hongen.com/eng/daily/sentence/0425sent.htm'
  t=Time.now
  m="%02d" % (t.sec%10+3)
  d="%02d" % t.day
  url = "http://ppcbook.hongen.com/eng/daily/sentence/#{m}#{d}sent.htm"
  begin
    page = agent.get_file(url)
  rescue Exception => e
    return e.message[0,60] + ' . IN osod'
  end
  s = page.match(/span class="e2">(.*?)<select name='selectmonth'>/mi)[1]
  s = s.gsub!(/\s+/,' ')
  s.gsub!(/<.*?>/,'').unescapeHTML.gb_to_utf8
end

#get deb info
def ge name
  agent = Mechanize.new
  agent.user_agent_alias = 'Linux Mozilla'
  agent.max_history = 1
  agent.open_timeout = 10
  agent.cookies
  begin
    url = 'http://packages.ubuntu.com/search?&searchon=names&suite=all&section=all&keywords=' + name.strip
    #url = 'http://packages.debian.org/search?suite=all&arch=any&searchon=names&keywords=' + name.strip
    #p url
    #page = agent.get(url)
    page = agent.get_file(url)
    #return nil if page.class != Mechanize::Page
  rescue Exception => e
    #p e.message
    return e.message[0,60] + ' . IN getdeb'
  end
  s = page.split(/<\/h2>/im)[1]
  s = s.match(/.*resultlink".+?:(.+?)<br>(.+?): .*<h2>/mi)[1..2].join ','
  s = s.gsub!(/\s+/,' ')
  s.gsub!(/<.*?>/,'')
  s.unescapeHTML
end
alias get_deb_info ge

def restart #Hard Reset
  exec "#{__FILE__} #$argv0"
end

#公告
def gg
  t=Time.now
"
⿻ 本频道#ubuntu-cn当前log地址是 :
http://logs.ubuntu-eu.org/free/#{t.strftime('%Y/%m/%d')}/%23ubuntu-cn.html
有需要请浏览 ,
. #{t.strftime('%H:%M:%S')}
"
end
#alias say_公告 say_gg

#简单检测代理是否可用
def check_proxy_status
  Thread.new do
    begin
      a=Timeout.timeout(15){TCPSocket.open $proxy_addr,$proxy_port}
    rescue Timeout::Error
      print $proxy_addr,':',$proxy_port,' ',false
      $proxy_status_ok = false
      return
    end
    print $proxy_addr,':',$proxy_port,' ',true
    $proxy_status_ok = true
    a.close
  end
end

