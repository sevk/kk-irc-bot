#让ruby1.8兼容1.9的写法
# -*- coding: utf-8 -*-

if RUBY_VERSION < '1.9'
  #为字符串类添加force_encoding和ord方法
  class String
    def prepend s
      self.replace s+self
    end

    def force_encoding(s)
      self
    end
    def ord
      self[0]
    end
  end
  #为Hash类添加key方法,1.8里面是 index 方法
  class Hash
    def key(k)
      self.index(k)
    end
  end
  #为数字类添加ord方法
  class Fixnum
    def ord
      self
    end
  end
end
