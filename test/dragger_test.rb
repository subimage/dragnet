require 'test_helper'

class DraggerTest < Test::Unit::TestCase
  context "Extracting content from microformat aware HTML" do
    setup do
      @net = Dragnet::Dragger.drag!(sample_with_microformat)
    end

    should "parse hEntry body as content" do
      assert(@net.content.include?("I got quite a vociferous e-mail today saying the only reason our Colorado polling was showing Michael Bennet and Bill Ritter"))
      assert_match(/Ritter\.$/, @net.content)
    end
    
    should "only extract links from hentry content" do
      assert_equal(@net.links.size, 0)
    end
    
    should "respect linebreaks" do
      @net = Dragnet::Dragger.drag!(load_data('microformat'))
      expected_match = /.*It makes me feel like I should be down in South Beach or something.\n\nCalled the.*/
      assert_match(expected_match, @net.content)
    end
  end # / microformat tests
  
  context "Extracting content" do
    
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
      
      should "respect linebreaks" do
        expected_match = /Multi-platinum and grammy award winning recording artist Deftones will make a tour stop in Louisville this Friday at Expo 5\. Supporting Deftones on the bill is The Dillinger Escape Plan and Le Butcherettes\..*\n\nThe Deftones, a post-grunge alt-metal band are one of the most emotionally charged musical acts to emerge since/
        assert_match(expected_match, @net.content)
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
    
  end # / extracting content
  
  context "Extracting author's name" do
    
    should "be able to parse vcard markup" do
      @net = Dragnet::Dragger.drag!(sample_with_microformat)
      assert_equal "Tom Jensen", @net.author
      
      @net = Dragnet::Dragger.drag!(sample_with_comment_link_at_top)
      assert_equal "Jason Jones", @net.author
    end
    
    should "be able to find author names if multiple classes applied to container" do
      @net = Dragnet::Dragger.drag!(load_data('microformat'))
      assert_equal "Chris Harris", @net.author
    end
    
    # For people adhering to google's markup standard outlined here:
    # http://googlewebmastercentral.blogspot.com/2011/06/authorship-markup-and-web-search.html
    should "find authors with google's authorship markup" do
      @net = Dragnet::Dragger.drag!(load_data('ny-times-article'))
      assert_equal "Sam Dolnick", @net.author
    end
    
    should "return nil if no author" do
      @net = Dragnet::Dragger.drag!(load_data('the-fix'))
      assert_nil @net.author
    end
    
    # 
    should "be able to parse strings for author's name" do
      @net = Dragnet::Dragger.drag!(load_data('caller-times'))
      assert_equal "Alan Sculley", @net.author
    end
  end
end
