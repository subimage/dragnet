class Nokogiri::XML::Node
  attr_accessor :content_score
  
  def word_count
    content.strip.split(' ').size
  end
end

module Dragnet
  class Dragger
    # Keywords known to commonly contain readable content
    STRONG_KEYWORDS = %w(
      blog 
      article 
      body 
      content 
      entry 
      hentry 
      post 
      story 
      text 
      post-entry 
      post-body 
      entry-content 
      blogpost 
      entry-body 
      page-post 
      postcontent 
      pbody 
      article-text 
      blogText
    )
    
    # Higher level containers known to contain content further down the heirarchy
    MEDIUM_KEYWORDS = %w(
      area 
      container 
      inner 
      main 
      story
    )
    
    # Keywords known to contain unwanted content
    IGNORE_KEYWORDS = %w(
      captcha 
      classified 
      comment 
      comments 
      commentText
      commentwrapper
      comnt 
      userComments
      footer 
      footnote 
      listing 
      menu 
      meta
      module 
      nav 
      navbar 
      sidebar 
      sbar 
      sponsor 
      tab 
      toolbar 
      tools 
      trackback 
      widget 
      trail
      toolbox 
      reply 
      addstrip
      stryTools 
      socialTools 
      relatedMedia 
      related
      submitted
      share
      print
      wp-caption-text
      caption
    )
    
    # Elements that we don't want to attempt to parse for content.
    # These elements are removed before parsing.
    INVALID_ELEMENTS = %w(
      form 
      link 
      head 
      object 
      iframe 
      h1 
      script 
      style 
      embed 
      param
    )
    
    INVALID_LINK_HOSTS = [
      'del.icio.us', 
      'digg.com', 
      'technorati.com', 
      'stumbleupon.com'
    ]
    
    INVALID_LINK_TEXT = [
      'email',
      'e-mail',
      'email article',
      'reddit',
      'retweet',
      'digg',
      'digg it',
      'del.icio.us',
      'technorati',
      'stumble',
      'stumbleUpon',
      'myspace',
      'report abuse',
      'print',
      'print article',
      'printable version',
      'permalink',
      'trackbacks',
      'trackback',
      'read more',
      'facebook',
      'yahoo buzz!',
      'yahoo! buzz',
      'mixx',
      'terms of service',
      'your ad here',
      'sphere it!',
      'share this',
      'share',
      'previous',
      'next comments',
      'links to this article',
      'my yahoo!',
      'google reader',
      'rss',
      'get this widget'
    ]
    
    CONTROL_SCORE = 20
    
    DEBUG = false
    DEBUG_CONTENT = 'Report abuse'
    
    attr_reader :content
    attr_reader :links
    attr_reader :author
    attr_reader :title
    
    def self.drag!(html)
      new(html)
    end
    
    def initialize(html)
      # Replace 2 or more BR tags with a paragraph
      html.gsub!(/(<br\s*[^>]*>\n*){2,}/i, "<p />")
      
      # Search backwards in the document for items with class names
      # or IDs with "comment".
      comment_node_pos = html.rindex(/(class|id)=.+comment.+/i)
      if comment_node_pos
        # Try to find opening tag.
        opening_tag_pos = html.rindex('<', comment_node_pos)
        # Kill all content after it.
        # It'll break our HTML, but Nokogiri is nice and fixes that for us.
        html = html[0, opening_tag_pos]
      end

      @doc = Nokogiri::HTML(html) 
      @title = @doc.at('//title').content rescue nil
      @links = []
      @high_score = -1
      parse!
    end
    
    def parse!
      # First try to extract the content as a microformat
      @content = parse_as_microformat(@doc)
      unless @content.nil?
        @content = cleanup_content(@content)
        @links = extract_links_from_content(@content)
        return
      end
      
      content = []
      content_containers = []
      
      # Remove all the stuff we don't want from the HTML
      INVALID_ELEMENTS.each do |ename|
        @doc.css(ename).each { |e| e.remove }
      end
            
      paragraphs = @doc.css('p').to_a
      
      # If we have no paragraphs or the paragraph content we got was empty
      # lets try another method
      empty = paragraphs.collect {|c| c.content.strip}.join('').empty?
      if paragraphs.size == 0 || empty
        paragraphs = @doc.css('div').to_a
      end
      
      paragraphs + @doc.css('blockquote').to_a
      paragraphs + @doc.children.collect {|c| c.is_a?(Nokogiri::XML::Text) }
      
      puts "Paragraphs: #{paragraphs.size}" if DEBUG
      
      paragraphs.each do |par|
        parent = par.parent
        parent.content_score = 0 if parent.content_score.nil?
        parent.content_score = build_score(parent, par)
        
        #puts "PSCORE:#{parent.content_score}" if DEBUG && parent.content.include?(DEBUG_CONTENT)
        
        if parent.content_score > 0    
          unless content_containers.include?(parent)
            content_containers << parent 
          end
        end
      end
      
      content_containers.uniq!
      content_containers.delete_if do |container|
        ((@high_score < CONTROL_SCORE) && (container.content_score < @high_score))
      end
      
      content_containers.delete_if do |container|
        ((@high_score > CONTROL_SCORE) && (container.content_score < @high_score))
      end
      
      
      # Remove content elements that are decendants of other content elements     
      if content_containers.size > 1
        content_containers.delete_if do |container|
          container.children.any? do |child|
            content_containers.include?(child)
          end
        end
      end
      
      # Remove all content elements whose children are all negative or 0 values.
      # Remove all children with negative or zero values
      content_containers.each do |container|
        # pp "CHILDREN:#{container.children.size}"
        # pp "WILDCARD:#{container.css('*').size}"
        if container.children.all? {|c| c.content_score && c.content_score <= 0}
          container.remove
        else
          container.css('*').each do |child|
            pp child.content_score if DEBUG and child.content.include?(DEBUG_CONTENT)
            child.remove if child.content_score && child.content_score <= 0
          end
        end
        # Extract all the links from what we assume is the content containers
        @links.concat(extract_links_from_content(container))
        content << get_text_from_container(container)
      end
      @content = content.join(' ')
    end  
    
    def cleanup_content(content)
      # Attempt to replace paragraph tags with linebreaks
      content.gsub!(/<p>/, '')
      content.gsub!(/<\/p>/, "\n")
      content.gsub!(/<br.*>/, "\n")
      #content.gsub!(/[\r\n\t]+/i, ' ')
      content.gsub!(/ {2,}/, ' ')
      # Kill all remaining HTML tags
      content.gsub!(/<\/?[^>]*>/, '')
      content.gsub!('<![CDATA[', '')
      content.gsub!(']]>', ' ')
      content.strip
    end
    
    # Returns a list of nodes, text + html.
    # Iterate through them and add our own line breaks.
    # Provides cleaner parsing.    
    def get_text_from_container(container_node)
      text = ""
      container_node.children.each do |node|
        text << node.text.gsub(/[\s^\n]{2,}/,' ')
        text << "\n\n" if %w(p div).include?(node.name)
      end
      return text.gsub(/[\n]{3,}/,"\n\n").strip
    end
    
    def build_score(parent, element)
      ancestors = parent.ancestors
      score = parent.content_score
      element_score = element.content_score || 0
      
      klasses = parent['class'].downcase rescue ''
      ancestor_klasses, ancestor_ids = keyword_collection_for(element)
      id = parent['id'].downcase rescue nil
      
      puts "SCORE FIRST:#{score}" if DEBUG && element.content.include?(DEBUG_CONTENT)
      # Two points for every strong keyword
      STRONG_KEYWORDS.each do |keyword|        
        score += 1 if klasses =~ /#{keyword}/i
        score += 1 if id && id =~ /#{keyword}/i
      end
      
      puts "SCORE STRONG:#{score}" if DEBUG && element.content.include?(DEBUG_CONTENT)
      
      # 1/2 point for every medium keyword
      if score >= 1
        MEDIUM_KEYWORDS.each do |keyword|
          score += 0.5 if klasses =~ /#{keyword}/i
          score += 0.5 if id && id =~ /#{keyword}/i
        end
      end
      
      puts "SCORE MEDIUM:#{score}" if DEBUG && element.content.include?(DEBUG_CONTENT)
      
      #Nuke the score for any bad or ignored keywords
      IGNORE_KEYWORDS.each do |keyword|
        score -= (CONTROL_SCORE * 0.3) if klasses =~ /#{keyword}/i
        score -= (CONTROL_SCORE * 0.3) if id && id =~ /#{keyword}/i        
        score -= 1 if ancestor_ids.join(' '). =~ /#{keyword}/i
        score -= 1 if ancestor_klasses.join(' ') =~ /#{keyword}/i
      end
            
      score += 1 if element.name == 'p' && element.word_count > CONTROL_SCORE       
      puts "SCORE FINAL:#{score}" if DEBUG && element.content.include?(DEBUG_CONTENT)
         
      @high_score = score if score > @high_score
      score
    end
    
    private
    
      def parse_as_microformat(doc)
        hEntry.find(:first, :text => doc.to_s).entry_content rescue nil
      end
      
      def extract_links_from_content(content)
        links = []
        content = Nokogiri::HTML.fragment(content) if content.is_a?(String)
        
        content.css('a').each do |link|
          href = link['href']
          if (href && !href.nil?) || (href && !href.empty?)
            begin
              url = URI.parse(href)
              text = link.content.strip.downcase.gsub(/\n+/, ' ')
              
              next if url.host.nil? || text.empty?
              next if INVALID_LINK_HOSTS.include?(url.host.downcase.to_s)
              found_invalid_link = false
              INVALID_LINK_TEXT.each do |bad_link_text|
                if text.index(/.*#{bad_link_text}.*/i) != nil
                  link.remove # Remove the bad link from our content.
                  found_invalid_link = true
                end
              end
              next if found_invalid_link

              links << {:text => link.content.strip, :href => href}
            rescue 
              
            end
          end          
        end
        links
      end
    
      def keyword_collection_for(element)
        ancestors = element.ancestors
        @ancestor_klasses ||= ancestors.collect {|c| c['class'] ? c['class'].split(' ') : nil }.flatten.uniq.compact
        @ancestor_ids ||= ancestors.collect {|c| c['id'] ? c['id'].split(' ') : nil }.flatten.uniq.compact
      
        [@ancestor_klasses, @ancestor_ids]
      end
    
  end
end