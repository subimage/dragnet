require 'test_helper'

class DraggerTest < Test::Unit::TestCase
  context "When extracting content from a page with an hEntry item" do
    setup do
      @net = Dragnet::Dragger.drag!(sample_with_microformat)
    end

    should "parse hentry body as content" do
      assert(@net.content.include?("I got quite a vociferous e-mail today saying the only reason our Colorado polling was showing Michael Bennet and Bill Ritter"))
      assert_match(/Ritter\.$/, @net.content)
    end
    
    should "only extract links from hentry content" do
      assert_equal(@net.links.size, 0)
    end
    
    should "respect linebreaks" do
      @net = Dragnet::Dragger.drag!(load_data('microformat'))
      expected_match = /.*I actually love the song &ldquo;You&rsquo;ve Seen The Butcher,&rdquo; from the Deftones&rsquo; most recent LP, Diamond Eyes\. But this&hellip;remix\? It makes me feel like I should be down in South Beach or something.\n\nCalled the &ldquo;Mustard Pimp remix,&rdquo; you can hear it here and download it here, too\..*/
      assert_match(expected_match, @net.content)
    end
  end
  
  context "When extracting content" do
    
    context "for pages with embedded links" do
      setup do
        @net = Dragnet::Dragger.drag!(sample_with_embedded_links)
      end
    
      should "ignore invalid content such as comments, etc. even if it shares the same parent as valid article content" do
        assert_no_match(/Report Abuse/, @net.content)
      end
    
      should "extract only links within the content area" do
        assert_equal("Polling done earlier this week by NBC", @net.links.first[:text])
        assert_equal("John Ensign", @net.links.last[:text])
        unwanted_link = @net.links.find{|l| l[:text] =~ /Get This Widget.+/i}
        assert unwanted_link.nil?, "Found unwanted link in link collection."
      end
    end # / embedded links
    
    context "for pages with heavy banners" do
      setup do
        @net = Dragnet::Dragger.drag!(sample_with_sidebars)
      end
      
      should "ignore print links in the content" do
        assert_no_match(/^Print/, @net.content)
      end
    end 
    
    context "for pages with comment links before content" do
      setup do
        @net = Dragnet::Dragger.drag!(sample_with_comment_link_at_top)
      end
      
      should "still return proper content, and not chop out body" do
        assert_match(
          /I hear they want a point guard/, @net.content,
          "Should have proper body content"
        )
        assert_no_match(
          /I actually really like Kimba, and he can score/, @net.content,
          "Should not contain first comment body"
        )
      end
    end
    
  end
end
