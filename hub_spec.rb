require 'hub'
require 'mocks'
require 'timeout'

HUB_URL = ENV['HUB_URL']
raise "Specify a hub URL by setting the HUB_URL environment variable." unless HUB_URL

def wait_on(something)
  begin
    Timeout::timeout(3) { break unless something.nil? while true }
  rescue Timeout::Error
    nil
  end
end

def as_optional
  # TODO: record as optional spec failure
end

shared_examples_for "a hub with publisher and subscriber" do
  before(:all) do
    @hub = Hub.new(HUB_URL)
    @publisher = Publisher.new(@hub)
    @subscriber = Subscriber.new(@hub)
  end

  after(:all) do
    @publisher.stop
    @subscriber.stop
  end
end

describe Hub, "publisher interface" do
  it_should_behave_like "a hub with publisher and subscriber"

  it "accepts POST request for publish notifications" do
    @hub.publish(@topic_url).should be_a_kind_of(Net::HTTPSuccess)
  end

  it "MUST return 204 No Content if publish notification was accepted" do
    @hub.publish(@topic_url).should be_an_instance_of(Net::HTTPNoContent)
  end

  it "MUST return appropriate HTTP error response code if not accepted" do
    @hub.post_as_publisher(nil, nil)          .should be_a_kind_of(Net::HTTPClientError)
    @hub.post_as_publisher('not publish', nil).should be_a_kind_of(Net::HTTPClientError)
  end

  it "SHOULD include a header field X-Hub-Subscribers whose value is an integer in content fetch request" do
    # Because GAE-PSH doesn't fetch content unless there are subscriptions, we subscribe
    @hub.subscribe(@subscriber.accept_callback_url, @topic_url, 'sync', Subscriber::VERIFY_TOKEN)

    @publisher.last_headers = nil
    @hub.publish(@topic_url)
    sleep 1
    wait_on @publisher.last_headers
    @publisher.last_headers.should include("X-Hub-Subscribers") rescue as_optional
  end

  it "SHOULD arrange for a content fetch request after publish notification" # shouldn't it always? Well, some hubs may have different rules, like a "blackout" period between 2 polls... etc

end

describe Hub, "subscriber interface" do
  it_should_behave_like "a hub with publisher and subscriber"
  
  before(:each) do
    @topic_url = ENV['TOPIC_URL'] || @publisher.content_url
  end

  context "when required arguments are missing or not right" do
    context "when the mode is not valid" do
      before(:each) do
        @res = @hub.post_as_subscriber('not subscribe', @subscriber.accept_callback_url, @topic_url, "sync")
      end
      it "should return an HTTP error code" do
        @res.should be_a_kind_of(Net::HTTPClientError)
      end
      it "should return an error message about the mode" do
        @res.body.to_s.strip.should match(/mode/)
      end
    end

    context "when the callback is not valid" do
      before(:each) do
        @res = @hub.post_as_subscriber('subscribe', nil, @topic_url, "sync")
      end
      it "should return an HTTP error code" do
        @res.should be_a_kind_of(Net::HTTPClientError)
      end
      it "should return an error message about the callback" do
        @res.body.to_s.strip.should match(/callback/)
      end
    end
    
    context "when the topic us no valid" do
      before(:each) do
        @res = @hub.post_as_subscriber('subscribe', @subscriber.accept_callback_url, nil, "sync")
      end
      it "should return an HTTP error code" do
        @res.should be_a_kind_of(Net::HTTPClientError)
      end
      it "should return an error message about the topic" do
        @res.body.to_s.strip.should match(/topic/)
      end
    end
    
    context "when the verify is not valid" do
      before(:each) do
        @res = @hub.post_as_subscriber('subscribe', @subscriber.accept_callback_url, @topic_url, nil)
      end
      it "should return an HTTP error code" do
        @res.should be_a_kind_of(Net::HTTPClientError)
      end
      it "should return an error message about the verify" do
        @res.body.to_s.strip.should match(/verify/)
      end
      
      it "MUST ignore verify keywords it does not understand" do
        @hub.subscribe(@subscriber.accept_callback_url, @topic_url, ['sync','foobar','async'], Subscriber::VERIFY_TOKEN).should be_a_kind_of(Net::HTTPSuccess)
      end
      
    end
  end

  context "when the verification is synchronous" do

    context "when verifying intent" do
      it "must verify subscriber with a GET request to the callback URL" do
        request_method = nil
        @subscriber.onrequest = lambda {|req| request_method = req.request_method }
        @hub.subscribe(@subscriber.accept_callback_url, @topic_url, 'sync', Subscriber::VERIFY_TOKEN)
        wait_on request_method
        request_method.should == "GET"
      end

      it "is REQUIRED to include mode, topic and challenge query parameters in the verification request" do
        query_string = nil
        @subscriber.onrequest = lambda {|req| query_string = req.query_string }
        @hub.subscribe(@subscriber.accept_callback_url, @topic_url, 'sync', Subscriber::VERIFY_TOKEN)
        wait_on query_string
        query_string.should include("hub.mode=")
        query_string.should include("hub.topic=")
        query_string.should include("hub.challenge=")
      end
    end
    
    context "when the subscriber's intent is verified" do
      it "MUST return 204 No Content" do
        @hub.subscribe(@subscriber.accept_callback_url, @topic_url, 'sync', Subscriber::VERIFY_TOKEN).should be_a_kind_of(Net::HTTPNoContent)
      end
    end
    
    context "when the subscriber's intent couldn't be verified" do
      it "MUST consider other client and server response codes to mean subscription is not verified" do
        @hub.subscribe(@subscriber.refuse_callback_url, @topic_url, 'sync', Subscriber::VERIFY_TOKEN).should be_a_kind_of(Net::HTTPClientError)
      end

      it "SHOULD return a description of an error when the subscription is refused" do
        @hub.subscribe(@subscriber.refuse_callback_url, @topic_url, 'sync', Subscriber::VERIFY_TOKEN).body.to_s.strip.should match(/callback/)
      end
    end
  end

  context "when the verification is asynchronous" do
    it "MUST return 202 Accepted if the subscription was created but has yet to be verified" do
      @hub.subscribe(@subscriber.accept_callback_url, @topic_url, 'async', Subscriber::VERIFY_TOKEN).should be_a_kind_of(Net::HTTPAccepted)
    end
  end

end
