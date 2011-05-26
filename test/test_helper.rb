$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), '..', 'lib'))
$LOAD_PATH.unshift(File.dirname(__FILE__))
require 'rubygems'
require 'test/unit'
require 'shoulda'
require 'dragnet'

class Test::Unit::TestCase
  def load_data(name)
    File.read(File.join(File.dirname(__FILE__), 'data', "#{name}.html"))
  end

  def sample_with_microformat
    load_data('public-policy-polling')
  end

  def sample_with_embedded_links
    load_data('the-fix')
  end
end
