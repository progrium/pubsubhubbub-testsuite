require 'net/http'
require 'uri'

begin
  require 'mechanize'
rescue LoadError
  require 'rubygems'
  require 'mechanize'
end

class Hub
  attr_reader :endpoint
  
  def initialize(endpoint)
    @endpoint = URI.parse(endpoint)
    @endpoint.path = '/' if @endpoint.path.empty?
    
    # This is for a hack to deal with non-auto running tasks on App Engine!?
    @is_gae = Net::HTTP.get(@endpoint.host, '/_ah/admin/queues', @endpoint.port).include?('Google')
  end

  def subscription_status(topic, callback, secret = nil)
    Net::HTTP.start(endpoint.host, endpoint.port) do |http|
      qs = "#{endpoint.query}&" || ''
      qs << "hub.mode=status&hub.callback=#{callback}&hub.topic=#{topic}"
      qs << "&hub.secret=#{secret}" if (secret)
      request = Net::HTTP::Get.new(endpoint.path + '?' + qs)
      response = http.request(request)
      if response.code.to_i == 200
        return response.body
      else
        return nil
      end
    end
  end
  
  def subscribe(callback, topic, verify, verify_token=nil, extra_params=nil)
    post_as_subscriber('subscribe', callback, topic, verify, verify_token, extra_params)
  end
  
  def unsubscribe(callback, topic, verify, verify_token=nil, extra_params=nil)
    post_as_subscriber('unsubscribe', callback, topic, verify, verify_token)
  end
  
  def publish(url)
    post_as_publisher('publish', url)
  end
  
  def post_as_subscriber(mode, callback, topic, verify, verify_token=nil, extra_params=nil)
    form_data = {
      'hub.mode' => mode,
      'hub.callback' => callback,
      'hub.topic' => topic,
    }
    form_data['hub.verify_token'] = verify_token if verify_token
    if verify.is_a? String
      form_data['hub.verify'] = verify
    elsif verify.is_a? Array
      # Part 1/2 of multivalue hack
      verify.each_with_index do |v, i|
        form_data["hub.verify--.#{i}"] = v
      end
    end

    if extra_params
      form_data.update(extra_params)
    end

    req = Net::HTTP::Post.new(@endpoint.path)
    req.form_data = form_data
    req.body = req.body.gsub(/\-\-\.\d/, '') # Part 2/2 of multivalue hack
    Net::HTTP.new(@endpoint.host, @endpoint.port).start do |http|
      http.request(req)
    end
  end
  
  def post_as_publisher(mode, url)
    res = Net::HTTP.post_form(@endpoint, {
      'hub.mode' => mode,
      'hub.url' => url,
    })
    run_feed_pull_task if @is_gae && res.kind_of?(Net::HTTPSuccess)
    return res
  end
  
  # In response to http://code.google.com/p/googleappengine/issues/detail?id=1796
  def run_feed_pull_task
    page = WWW::Mechanize.new.get("http://#{@endpoint.host}:#{@endpoint.port}/_ah/admin/tasks?queue=feed-pulls")
    payload = page.form_with(:action => '/work/pull_feeds')['payload'] rescue nil
    return unless payload
    Net::HTTP.start(@endpoint.host, @endpoint.port) {|http| http.request_post('/work/pull_feeds', payload, {'X-AppEngine-Development-Payload'=>'1'}) }
    page.form_with(:action => '/_ah/admin/tasks').click_button # Delete the task
  end
end
