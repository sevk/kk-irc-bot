
$: << '.'
require 'rubygems'
require "test/unit" 
require 'test/unit/ui/console/testrunner'

require 'lib/dic.rb'

class TestNet < Test::Unit::TestCase 
  def test_ssl
    s = 'https://www.alvinren.xyz/test.php'
    r = gettitle s
    assert_match /test/i , r, ' test ssl fail '
  end
end

Test::Unit::UI::Console::TestRunner.run(TestNet )


