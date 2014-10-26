---
kk-irc-bot
irc-bot , like a human
---

=======

## Installation and usage

需要安装ruby :
建议装 ruby 2.0 或更高

#### windows : http://tiny.cc/install_ruby_win (可能需要翻墙)

#### linux下面建议用 rvm或rbenv 安装ruby :
* rbenv: http://ruby-china.org/wiki/rbenv-guide
rbenv install 2.1.0-dev
* rvm: https://rvm.io/rvm/install/

如果不是rvm或rbenv安装的ruby,需要额外安装ruby 头文件：
* ruby-dev    - Header files for compiling extension modules for Ruby (default version)

## 装完ruby后升级 gem, 
* 先把gem 服务器改成淘宝的 http://ruby.taobao.org/
* 然后命令: gem update --system
* 然后安装库, cd 到bot 目录 : gem install bundler && bundle

## 运行:
ruby irc.rb 或 ./irc.rb 

直接双击 irc.rb 也行，但出错后，cmd窗口会消失，看不到出错信息。

配置文件是 default.conf

###  指定其他配置文件运行：

      cp default.conf xx.conf ,
      修改 xx.conf ,
      运行: ruby irc.rb xx.conf  或 ./irc.rb xx.conf

* Core Team Members
 sevk

License
-------
MIT

