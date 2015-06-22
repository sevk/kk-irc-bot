---
kk-irc-bot
irc-bot , like a human
---

=======

## Installation and usage

需要安装ruby :
建议装 ruby 2.0 或更高

#### windows : http://tiny.cc/install_ruby_win (可能需要翻墙)

#### linux下面随意 :

* 系统软件包管理器，自己编译， rbenv , rvm 等

* 比如 :apt-get install ruby ruby-dev

## 装完ruby后升级 gem :

* 安装gem : cd 到bot 目录 : gem install bundler && bundle


## 运行:

ruby irc.rb 或 ./irc.rb 

直接双击 irc.rb 也行.

配置文件是 default.conf

###  指定其他配置文件运行：

      cp default.conf xx.conf ,
      修改 xx.conf ,
      运行: ruby irc.rb xx.conf  或 ./irc.rb xx.conf

License
-------
MIT


## PS:
* 包括测试库:  ▶ bundle install --standalone test
* 执行测试: ▶ ruby test/test.rb

