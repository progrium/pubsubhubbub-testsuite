require 'common'

# Publishing
# http://pubsubhubbub.googlecode.com/svn/trunk/pubsubhubbub-core-0.2.html#publishing
#
# Section 7
#

describe Hub, "interface for publishers" do
  it_should_behave_like "all hubs with a publisher and subscriber"

  # New Content Notification Requests - Core Requirements
  # http://pubsubhubbub.googlecode.com/svn/trunk/pubsubhubbub-core-0.2.html#anchor9
  
  # Section 7.1
  it "MUST accept POST requests for publish notifications" do
    @hub.publish(@topic_url).should be_a_kind_of(Net::HTTPSuccess)
  end

  it "MUST reject non-POST requests for subscription requests" do
    uri = @hub.endpoint.dup
    uri.query = "hub.mode=publish&hub.url=http://example.com/"

    Net::HTTP.start(uri.host, uri.port) do |http|
      req = Net::HTTP::Get.new(uri.request_uri)
      http.request(req).should be_a_kind_of(Net::HTTPClientError)
    end
  end

  it "MUST reject POST bodies that are not application/x-www-form-urlencoded" do
    uri = @hub.endpoint.dup
    uri.query = "hub.mode=publish&hub.url=http://example.com/"

    Net::HTTP.start(uri.host, uri.port) do |http|
      req = Net::HTTP::Post.new(uri.request_uri)
      req['Content-type'] = 'application/json'
      req.body = '{"hub.mode":"publish","hub.url":"http://example.com/"}'

      http.request(req).should be_a_kind_of(Net::HTTPClientError)
    end
  end

  it "MUST return an error if the hub.mode parameter is omitted from the request" do
    @hub.post_as_publisher(nil, 'http://example.com/').should be_a_kind_of(Net::HTTPClientError)
  end

  it "MUST return an error if the hub.url parameter is omitted from the request" do
    @hub.post_as_publisher('publish', nil).should be_a_kind_of(Net::HTTPClientError)
  end
  
  it "MUST return 204 No Content if publish notification was accepted" do
    @hub.publish(@topic_url).should be_an_instance_of(Net::HTTPNoContent)
  end
  
  # Section 7.2
 
  it "MUST send an HTTP GET request to the hub.topic URL to fetch the content" do
    # Because GAE-PSH doesn't fetch content unless there are subscriptions, we subscribe
    @request_mode = 'subscribe'
    doRequest()
    
    @publisher.last_request_method = nil
    @hub.publish(@topic_url)

    wait_for { @publisher.last_request_method != nil }
    @publisher.last_request_method.should == "GET"
  end

  # Section 7.3
  it "MUST send subscribers notification via an HTTP POST request to their callback URL" do
    request = get_publish_notification
    request.method.should == 'POST'
  end

  it "MUST send notification requests with a Content-Type of application/atom+xml" do
    request = get_publish_notification
    request.headers['content-type'].should == 'application/atom+xml'
  end

  it "MUST include new and changed entries as an Atom feed document in the body of the notification" do
    request = get_publish_notification
    pending("check content of atom entries to find changed content.")
  end

  it "MUST reproduce the atom:id element exactly" do
    request = get_publish_notification
    pending("verify atom:id elements")
  end
  
  # Section 7.4
  context "with a hub.secret parameter" do
    it "MUST generate an X-Hub-Signature header for notifications" do
      @request_mode = 'subscribe'
      secret = 'N0tPubl1cK'
      doRequest(:params => {'hub.secret' => secret})

      request = nil
      @subscriber.on_request = lambda { |req, res| request = req }

      @hub.publish(@topic_url)

      wait_for { request != nil }

      request.should_not be_nil
      request.headers.should have_key('X-Hub-Signature')
      pending do
        signature = HMAC::SHA1.hexdigest(secret, 'the-content')
        request.headers['X-Hub-Signature'].should == "sha1=#{signature}"
      end
    end
  end

end
