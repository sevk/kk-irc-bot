
require 'open-uri'

#自动检测适合的服务器
slist = ['http://ruby.taobao.org', 'https://rubygems.org']
slist.each{|x|
  #p ' check: ' + x
  Thread.new do
    if not $best_gemsrv
      if open(x).read(100)
        Thread.exit if $best_gemsrv
        $best_gemsrv = true
        p ' use ' + x
        source x
      end
    end
  end
}

sleep 0.1 while not $best_gemsrv

gem "mechanize"
gem "colored"
gem "htmlentities"
gem "rchardet19"
gem "qqwry"
gem "filesize"
gem 'google-search'
gem 'ansi' #console color
gem 'sinatra'
group :test do
  gem "test-unit"
end
#gem 'pry'
#gem "image_size"


