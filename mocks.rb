require 'webrick'

class Subscriber
  PORT = (ENV['SUB_PORT'] || 8089).to_i
  VERIFY_TOKEN = 'qfwef9'
  
  attr_reader :accept_callback_url, :refuse_callback_url
  attr_accessor :on_request
  
  def initialize(hub)
    @hub = hub
    @server = WEBrick::HTTPServer.new(:Port => PORT, :Logger => WEBrick::Log.new(nil, 0), :AccessLog => WEBrick::Log.new(nil, 0))
    @accept_callback_url = "http://localhost:#{PORT}/accept_callback_url"
    @refuse_callback_url = "http://localhost:#{PORT}/refuse_callback_url"

    @on_request = lambda {|req,res|}

    mount "/accept_callback_url" do |req,res|
      desired_response = on_request.call(req, res)

      desired_response = {} unless desired_response.respond_to?(:has_key?)
      
      if req.request_method == 'GET'
        res.status = desired_response['status'] || 200

        params = CGI.parse(req.query_string)
        res.body = desired_response['body'] || params['hub.challenge'].last
      else
        res.status = 404
        res.body = 'NOT THE CHALLENGE PARAMETER'
      end
    end

    mount "/refuse_callback_url" do |req, res|
      on_request.call(req, res)
      res.status = 404
      res.body = "Nope. I refuse this subscription."
    end

    @server_thread = Thread.new do 
      trap("INT"){ @server.shutdown }
      @server.start
    end
  end
  
  def mount(path, &block)
    @server.mount(path, WEBrick::HTTPServlet::ProcHandler.new(block))
  end
  
  def stop
    @server.shutdown
    @server_thread.join
  end
end

class Publisher
  HOST = ENV['PUB_HOST'] || 'localhost'
  PORT = (ENV['PUB_PORT'] || 8088).to_i

  
  attr_reader :content_url
  attr_reader :content
  attr_accessor :on_request
  
  attr_accessor :last_request_method
  attr_accessor :last_headers
  
  def initialize(hub)
    @hub = hub
    @server = WEBrick::HTTPServer.new(:Port => PORT, :Logger => WEBrick::Log.new(nil, 0), :AccessLog => WEBrick::Log.new(nil, 0))
    @content_url = "http://localhost:#{PORT}/happycats.xml"
    @last_request_method = nil
    @last_headers = nil
    @on_request = lambda {|req, res|}
    @content =<<EOF
<?xml version="1.0"?>
<feed>
  <!-- Normally here would be source, title, etc ... -->

  <link rel="hub" href="#{@hub.endpoint}" />
  <link rel="self" href="#{@content_url}" />
  <updated>2008-08-11T02:15:01Z</updated>

  <!-- Example of a full entry. -->
  <entry>
    <title>Heathcliff</title>
    <link href="http://publisher.example.com/happycat25.xml" />
    <id>http://publisher.example.com/happycat25.xml</id>
    <updated>2008-08-11T02:15:01Z</updated>
    <content>
      What a happy cat. Full content goes here.
    </content>
  </entry>

  <!-- Example of an entity that isn't full/is truncated. This is implied
       by the lack of a <content> element and a <summary> element instead. -->
  <entry >
    <title>Heathcliff</title>
    <link href="http://publisher.example.com/happycat25.xml" />
    <id>http://publisher.example.com/happycat25.xml</id>
    <updated>2008-08-11T02:15:01Z</updated>
    <summary>
      What a happy cat!
    </summary>
  </entry>

  <!-- Meta-data only; implied by the lack of <content> and
       <summary> elements. -->
  <entry>
    <title>Garfield</title>
    <link rel="alternate" href="http://publisher.example.com/happycat24.xml" />
    <id>http://publisher.example.com/happycat25.xml</id>
    <updated>2008-08-11T02:15:01Z</updated>
  </entry>

  <!-- Context entry that's meta-data only and not new. Implied because the
       update time on this entry is before the //atom:feed/updated time. -->
  <entry>
    <title>Nermal</title>
    <link rel="alternate" href="http://publisher.example.com/happycat23s.xml" />
    <id>http://publisher.example.com/happycat25.xml</id>
    <updated>2008-07-10T12:28:13Z</updated>
  </entry>

</feed>
EOF
    mount "/happycats.xml" do |req,res|
      @on_request.call(req, res)
      @last_request_method = req.request_method
      @last_headers = req.header
      res.status = 200
      res['Content-Type'] = 'application/atom+xml'
      res.body = @content
    end
    @server_thread = Thread.new do 
      trap("INT"){ @server.shutdown }
      @server.start
    end
  end
  
  def mount(path, &block)
    @server.mount(path, WEBrick::HTTPServlet::ProcHandler.new(block))
  end
  
  def stop
    @server.shutdown
    @server_thread.join
  end
end
