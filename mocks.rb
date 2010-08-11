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
        res.status = desired_response['status'] || 404 
        res.body = desired_response['body'] || 'NOT THE CHALLENGE PARAMETER'
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
    set_content(:first)
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

  def set_content(which, format = 'atom')
    raw_content = File.read("feeds/#{which}.#{format}")
    escaped_content = "'#{raw_content.gsub(/'/m, '\\\\\'')}'"
    @content = eval(escaped_content)
  end
  
  def stop
    @server.shutdown
    @server_thread.join
  end
end
