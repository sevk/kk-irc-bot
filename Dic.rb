#!/usr/bin/env ruby
# coding: utf-8
# Sevkme@gmail.com

begin
  #安装 mechanize:
  #sudo gem install mechanize
  #require 'mechanize'

  #sudo apt-get install rubygems
  require 'rubygems' #以便引用相关的库

  #gem install htmlentities
  require 'htmlentities'

rescue LoadError
  puts "载入相关的库时错误,应该在终端下执行以下命令:\nsudo apt-get install rubygems; #安装ruby库管理器 \nsudo gem install htmlentities; #安装htmlentities库 \n\n"
  puts $@
  exit
end

begin
  require 'charguess.so'
rescue LoadError
end
require 'open-uri'
require 'iconv'
require 'uri'
require 'net/http'
require 'rss/1.0'
require 'rss/2.0'
#require 'cgi'
require 'base64'
#require 'md5'
require 'resolv'
#require 'pp'
load 'do_as_rb19.rb'
load 'color.rb'
require 'yaml'

#todo http://www.sharej.com/ 下载查询
#todo http://netkiller.hikz.com/book/linux/ linux资料查询
$old_feed_size = 0

Help = '我是 kk-irc-bot ㉿ s 新手资料 g google d define `new 取论坛新贴 `b baidu tt google翻译 `t 词典 `host 查域名 >1+1 计算 `a 查某人地址 `f 查老乡 `i 机器人源代码. 末尾加入|重定向,如 g ubuntu | nick'
Delay_do_after = 4
Ver='v0.25' unless defined?(Ver)
UserAgent="kk-bot/#{Ver} (X11; U; Linux i686; en-US; rv:1.9.1.2) Gecko/20090810 Ubuntu/9.10 (karmic) kk-bot/#{Ver}"

CN_re=/[\u4E00-\u9FA5]+/
Http_re= /http:\/\/\S+[^\s*]/

Minsaytime= 3
puts "最小说话时间=#{Minsaytime}"
$min_next_say = Time.now
$Lsay=Time.now; $Lping=Time.now
$lag=1

puts "$SAFE= #$SAFE"
NoFloodAndPlay=/\-ot|arch|fire/i
$botlist=/bot|fity|badgirl|crazyghost|u_b|iphone|^\^O_|^O_|^A_U.?$|MadGirl|Psycho/i
$botlist_Code=/badgirl|^O_|^\^O_|^A_U.?$/i
$botlist_ub_feed=/crazyghost|^O_|^\^O_|^A_U.?$/i
$botlist_title=/GiGi|u_b|^O_|^\^O_|^A_U.?$/i
$tiList=/ub|deb|ux|ix|win|goo|beta|py|ja|lu|qq|dot|dn|li|pr|qt|tk|ed|re|rt/i
$urlList=$tiList

def URLDecode(str)
  #str.gsub(/%[a-fA-F0-9]{2}/) { |x| x = x[1..2].hex.chr }  
  URI.unescape(str)
end

def URLEncode(str)
  #str.gsub(/[^\w$&\-+.,\/:;=?@]/) { |x| x = format("%%%x", x.ord) }  
  URI.escape(str)
end

def unescapeHTML(str)
  HTMLEntities.new.decode(str)
  #CGI.unescapeHTML(str)
end 

#字符串编码集猜测,只取参数的中文部分
def guess_charset(str)
  s = str.gsub(/[\x0-\x7f]/,'')
  return nil if s.bytesize < 4
  while s.bytesize < 25
    s = s + s
  end
  return guess(s)
end

if defined?CharGuess
  def guess(s)
    CharGuess::guess(s)
  end
else
  #第二种字符集猜测库
  require 'rchardet'
  def guess(s)
    CharDet.detect(s)['encoding'].upcase
  end
end

#如果当前目录存在UBUNTU新手资料.txt,就读取.
def readDicA()
  fi1= 'UBUNTU新手资料.txt'
  if (File.exist?fi1 )
    IO.read(fi1)
  else
    ''
    #'http://linuxfire.com.cn/~sevk/UBUNTU新手资料.php'
  end
end
def loadDic()
  $str1 = readDicA
  puts 'Dic load [ok]'
end
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
    begin
      result = yield
    rescue Exception => detail
      result = detail.message()
    end
  }.join
  result
end

class Rss_reader
  attr_accessor :title, :pub_date, :description, :link
end
#取ubuntu.org.cn的 feed.
def get_feed(url= 'http://forum.ubuntu.org.cn/feed.php',not_re = true)
  @rss_str = Net::HTTP.get(URI.parse(url)).force_encoding("utf-8")
  @rss_str = @rss_str.gsub(/\s+/,' ')
  xml_doc = REXML::Document.new(@rss_str)
  return nil unless xml_doc
  re = Array.new
  $ub = ''
  xml_doc.elements["rss/channel"].each_element("//item") do |ele|
    reader = Rss_reader.new
    reader.title = ele.elements["title"].get_text
    reader.pub_date = ele.elements["pubDate"].get_text
    reader.description = ele.elements["description"].get_text
    reader.link = ele.elements["link"].get_text
    re << reader

    next if reader.title.to_s =~ /^Re:/i && not_re 
    #puts reader.title.to_s
    $ub = "新⇨ #{reader.title} #{reader.link} #{reader.description}"
    $ub = unescapeHTML($ub)
    $ub.gsub!(/<.+?>/,' ')
    break
  end
  puts $ub
  if $old_feed_size == $ub.size
    $ub = nil
    return 'hehe,去论坛逛了一下，暂时无新帖.'
  else
    $old_feed_size = $ub.size
  end
  return $ub
end

#google 全文翻译,参数可以是中文,也可以是英文.
def getGoogle_tran(word) 
  if word =~/^[\u4E00-\u9FA5]+$/#有中文
    flg = 'zh-CN%7Cen'
    #flg = '#auto|en|' + word ; puts '中文>英文'
  else
    flg = 'auto%7Czh-CN'
    #flg = '#auto|zh-CN|' + word
  end
  word = URI.escape(word)
  puts word
  #url = "http://66.249.89.100/translate_t?hl=zh-CN#{flg}"
  #66.249.89.100 = translate.google.com
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
    |f| p f.content_type
    return f.read
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

def dictcn(word)
  word = word.utf8_to_gb
  
  #url = 'http://api.dict.cn/api.php?utf8=true&q=' + word
  url = 'http://dict.cn/mini.php?q=' + word
  url = URI.escape(url)
  puts url
  uri = URI.parse(url)
  begin #加入错误处理
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
      p f.content_type
      re = f.read[0,5059].force_encoding('utf-8').gsub(/\s+/,' ').gb_to_utf8
      re.gsub!(/<script.*?<\/script>/i,'')
      re.gsub!(/<.*?>/i,'')
      re.gsub!(/.*?Define /i,'')
      return unescapeHTML(re) + ' << Dict.cn'
    }
  rescue 
    return $!
  end
end

#取标题,参数是url.
def gettitle(url)
    title = $tmp = ''
    charset = ''
    flag = 0
    istxthtml = false
    if url =~ /[\u4E00-\u9FA5]/
      url = URI.encode(url)
    end
    #puts url.red
    uri = URI.parse(url)
    begin #加入错误处理
        uri.open(
        'Accept'=>'image/gif, image/x-xbitmap, image/jpeg, image/pjpeg, application/x-shockwave-flash, */*',
        'Referer'=> URI.encode(url),
        'Accept-Language'=>'zh-cn',
        #'Cookie' => cookie,
        #'Range' => 'bytes=0-9999',
        'User-Agent'=> UserAgent
        ){ |f|
          #p f.content_type
          istxthtml= f.content_type =~ /text\/html|application\/octet-stream/i
          charset= f.charset          # "iso-8859-1"
          $tmp = f.read[0,9999].gsub(/\s+/,' ')
        }
    rescue 
      return $!
    end
    return nil unless istxthtml

    tmp = $tmp
    tmp.match(/<title.*?>(.*?)<\/title>/i) rescue nil
    title = $1.to_s
    #puts title.green

    if title.bytesize < 1
      if tmp.match(/meta\shttp-equiv="refresh(.*?)url=(.*?)">/i)
        p 'refresh..'
        return gettitle("http://#{uri.host}/#{$2}")
      end
    end

    return nil if title =~ /index of/i

    #puts "1=" + charset.to_s
    tmp.match(/<meta.*?charset=(.+?)["']/i)
    charset=$1 if $1
    if charset =~ /^gb/i
      charset='gb18030' 
    end
    #puts '2=' + charset.to_s

    #tmp = guess_charset(title * 2).to_s
    #charset = 'gb18030' if tmp == 'TIS-620'
    #charset = tmp if tmp != ''
    #return title.force_encoding(charset)
    
    title = Iconv.conv("UTF-8","#{charset}//IGNORE",title).to_s rescue title
    title = unescapeHTML(title) rescue title
    #puts title.blue
    title
end

def getPY(c)
  c=' '+ c
  c.gsub!(/\sfirefox(.*?)\s/i,' huohuliulanqi ')
  c.gsub!(/\subuntu/i,' wu ban tu ')
  c.gsub!(/\sEnglish/i,' ying yu ')
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

  if re=~CN_re#是中文才返回
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
          tmp = html.match(/>网页<.+?(搜索用时|>网页<\/b>)(.*?)(搜索结果|Google 主页)/)[2]
        when /calc_img\.gif(.*?)Google 计算器详情/i #是计算器
          tmp = '<' +$1.to_s + ' Google 计算器' #(.*?)<li>
        else
          matched = false
        end
        #p;puts html.match(/搜索用时(.*?)搜索结果<\/h2>(.*?)网页快照/i)[0]
        if matched or html =~ /搜索用时(.*?)搜索结果<\/h2>(.*?)网页快照/i
          if !matched
            #puts ' tmp=' + $2.to_s
            tmp =$2.gsub(/<cite>.+<\/cite>/,' ' + url_mini)
            #puts ' tmp1=' + tmp1.to_s
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
            tmp.gsub!(/alt="/,'>')
            tmp.gsub!(/"\stitle=/,'<')
            tmp.gsub!(/\s\/\s/,"\/")
            tmp.gsub!(/级/, '级 ' )
            tmp.gsub!(/今日\s+/, ' 今日' )
            tmp.gsub!(/<\/b>/, ' ')
            tmp.gsub!(/添加到(.*?)当前：/,' ')
            #tmp.gsub!(/北京市专业气象台(.*)/, '' )
            tmp=tmp.match(/.+?°C.+?°C.+?°C/)[0]
            tmp.gsub!(/°C/,'°C ')
          end
          tmp.gsub!(/(.*秒）)|\s+/i,' ')
          #~ puts html
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

def geted2kinfo(url)
  url.match(/^:\/\/\|(\w+?)\|(\S+?)\|(.+?)\|.*$/)
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
      re= re.gsub(/<.*?>/i,'')[0,330]
      $re =  a2 + ' ' +  re
      $re = unescapeHTML($re)
      $re =  Iconv.conv("UTF-8//IGNORE","gb2312//IGNORE",$re).to_s[0,980]
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
        re.gsub!(/<.*?>/,'')
        re = re[0,600]
        re.gsub!(/&nbsp/,' ')
        re = unescapeHTML(re)
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
  def hm()
    "#{Time.now.strftime('[%H:%M]')}"
  end
  def ch()
    ' ' + chr_hour.to_s
  end
end

$last_time_min = Time.now
def time_min_ai()
  if Time.now - $last_time_min > 900
    $last_time_min = Time.now
    return " #{Time.hm}"
  end
end

def time_min()
  " #{Time.now.strftime('[%H:%M]')}"
end

#ch,小时字符. '㍘' = 0x3358
def chr_hour()
  if Time.now - $last_time_min > 1800
    $last_time_min = Time.now
    if RUBY_VERSION < '1.9'
      "\xE3\x8D"+ (Time.now.hour + 0x98).chr
    else
      (Time.now.hour + 0x3358).chr("UTF-8")
    end
  end
end

#取IP地址的具体位置,参数是IP
def getaddr_fromip(ip)
  hostA(ip,true)
end

def host(domain)#处理域名
  return 'IPV6' if domain =~ /^([\da-f]{1,4}(:|::)){1,6}[\da-f]{1,4}$/i
  return domain unless domain.include?('.')
  domain=domain.match(/^[\w\.\/\-\d]*/)[0]
  begin
    return Resolv.getaddress(domain)
  rescue Exception => detail
    puts detail.message()
    p $@
    domain
  end
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
  #return '操作不安全' if s=~/pass|serv/i
  return if s !~ /\d/ and s.size < 6
  result = nil
  begin
    #p s
    Timeout.timeout(4) {
      result = safe(4) {eval(s).to_s[0,400]}
    }
  rescue Exception => detail
    result = detail.message()
  end
  return result
end

#为字符串添加2个方法,用于gb18030和utf8互转.
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
  def ee(s=['☘',"\322\211"][rand(2)])
    self.split(//u).join(s)
  end
end



