
require 'htmlentities'
require 'mechanize'
require 'open-uri'
require 'utf.rb'
require 'log.rb'
require 'global.rb'
load 'color.rb'
load 'showpic.rb'

#取标题,参数是url.
def gettitle(url,proxy=true,mechanize=1)
  if not proxy and url =~  %r'^http://detail\.tmall\.com/item\.htm'i 
    return gettaobao url 
  end
  jg = nil
  if not proxy and url =~ %r'^http://item\.jd\.com/(\d+)\.html'i
    sjd = "http://p.3.cn/prices/get?skuid=J_#{$1}&type=1"
    jg = getjd_price sjd
  end
  timeout=7
  title = ''
  charset = ''
  if url.b =~ CN_re
    url = URI.encode(url)
  end

  if mechanize == 1
    mechanize = false if url =~ $urlNoMechanize
  else
    mechanize = true
  end
  mechanize = true if url =~ /www\.google\.com/i
  mechanize = true if url =~ $urlProxy
  mechanize = true if proxy
  print ' mechanize:' , mechanize , ' ' , url ,10.chr unless mechanize

  return gettitle_openURI url if not mechanize

  #用代理加快速度
  agent = Mechanize.new

  print ' proxy:' , proxy
  if proxy and url !~ /\.jetbrains\./i
    if $proxy_status_ok
      agent.set_proxy($proxy_addr2,$proxy_port2)
    else
      agent.set_proxy($proxy_addr,$proxy_port)
    end
  end
  agent.user_agent_alias = 'Linux Mozilla'
  agent.max_history = 0
  agent.open_timeout = timeout
  agent.read_timeout = timeout
  #agent.cookies
  #agent.auth('^k^', 'password')

  begin
    page = agent.head(url)
    #File.new('/tmp/h.x','wb').puts page.header
    type = page.header['content-type']
    #print 'get head ok: '
    if type =~ /image\/./i
      showpic(url)
      return type
    end
    if type and type !~ /^$|text\/html|octet-stream/i
      p page.response.select{|x| x=~/^content-(len|type)/i }
      re = page.response.select{|x| x=~/^content-(len|type)/i }
        .map{|x,y| "#{x}=#{y}" }.join(" ; ")
        .gsub(/content-/i,'')[0,90]
      return if re =~ /length=\d\D/i
      return re.gsub(/(length=)(\d+)/i){ "长度="+Filesize.from($2+'b').pretty }
    end
  rescue
    print 'err in get head: '
    p $!
    case $!
    when Mechanize::ResponseCodeError
      if $!.message !~ /^403/ and proxy and $proxy_status_ok
        #sleep timeout
        #return $!.message + 'in get head'
      end
    end
  end

  begin
    page = agent.get(url)
    #File.new('/tmp/a.x','wb').puts page.title
    #File.new('/tmp/b.x','wb').puts Mechanize.new.get_file url
    if page.class != Mechanize::Page
      p 'no page'
      return
    end
    title = page.title
    title = nil if title.empty?
    charset= guess_charset(title)
    charset='GB18030' if charset =~ /^IBM855|windows-1252/i

    if charset and charset !~ /#@charset/i
      title = title.code_a2b(charset,@charset) rescue title
    end
    title = title.unescapeHTML
    auth = page.at('.postauthor').text.strip rescue nil
    title << " zz: #{auth} " if auth
    [ '.tb-rmb-num' , '.priceLarge' ,'.tm-price', '.price',
      '.mainprice'
    ] .each {|x|
      break if jg
      jg = page.at(x).text.strip rescue nil
    }
    jg = nil if url =~ /\.douban\.com/i
    if jg and jg != ''
      title << " pp: #{jg[0,24]} "
    end
    return title[0,300] if title
  rescue
    print " err in get url:"
    log ''
    case $!
    when Mechanize::ResponseCodeError
      sleep timeout
      return $!.message if $!.message !~ /^403/
    end
  end

  gettitle_openURI url
rescue Exception
  log ''
  $!.message
end

def gettitle_openURI url
  print 'U'
  #puts URI.split url
  #  p ' use URI.open '

  timeout = 7
  istxthtml = false
  charset = nil
  tmp =
    begin #加入错误处理
      Timeout.timeout(timeout) {
        $uri = URI.parse(url)
        $uri.open(
          #'Accept'=>'text/html , application/*',
          'Range' => 'bytes=0-8999',
          #'Cookie' => cookie,
        ){ |f|
          case f.content_type
          when /application\/octet-stream/i
            istxthtml = false
          when /image\/./i
            showpic(url)
            istxthtml = false
          when /text\/html|application\//i
            #p f.content_type
            istxthtml= true
          end

          return f.content_type unless istxthtml
          charset= f.charset          # "iso-8859-1"
          f.read[0,9800].gsub(/\s+/,' ')
        }
      }
    rescue Timeout::Error
      sleep timeout
      return "取标题超时 #{$!.message}"
    rescue
      p ' err in URI.open '
      p $!
      if $!.message =~ /Connection reset by peer/ && $proxy_status_ok
				p ' need pass wall '
				return
      end
      sleep timeout
      return "取标题 #{$!.message[0,210] }"
    end

  return unless istxthtml

  title = tmp.match(/<title.*?>(.*?)<\/title>/i)[1] rescue ''

  if title.empty?
    p tmp
    if tmp.match(/meta\shttp-equiv="refresh(?:.*?)url=(.*?)">/i)
      p 'refresh..'
      return Timeout.timeout(timeout){
        url = $1
        url = "http://#{$uri.host}/#{url}" if url !~ /^http/i
        gettitle(url)
      }
    end
  end

  #return if title =~ /index of/i
  charset= guess_charset(title)
  charset='GB18030' if charset =~ /^IBM855|windows-1252/i

  if charset !~ /#@charset/i
    title = title.code_a2b(charset,@charset) rescue title
  end

  return '取标题: no title' if title.empty?
  title = title.unescapeHTML rescue title
  title
end


